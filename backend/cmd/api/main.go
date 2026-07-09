package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/navel/ci_watcher/backend/internal/config"
	"github.com/navel/ci_watcher/backend/internal/githubapp"
	"github.com/navel/ci_watcher/backend/internal/auth"
	"github.com/navel/ci_watcher/backend/internal/handler"
	"github.com/navel/ci_watcher/backend/internal/migrate"
	"github.com/navel/ci_watcher/backend/internal/store"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	ctx := context.Background()

	db, err := store.New(ctx, cfg.DatabasePath)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer db.Close()

	if err := migrate.Up(ctx, db.DB()); err != nil {
		log.Fatalf("migrate: %v", err)
	}

	githubClient, err := githubapp.New(cfg.GitHubAppID, cfg.GitHubPrivateKey)
	if err != nil {
		log.Fatalf("github app client: %v", err)
	}

	authHandler := auth.NewHandler(cfg, db, githubClient)

	router := chi.NewRouter()
	router.Use(middleware.RequestID)
	router.Use(middleware.RealIP)
	router.Use(middleware.Recoverer)
	router.Use(middleware.Timeout(60 * time.Second))

	router.Get("/health", handler.Health)

	router.Route("/v1", func(r chi.Router) {
		r.Post("/auth/start", authHandler.Start)
		r.Get("/auth/callback", authHandler.Callback)
		r.Post("/auth/token", authHandler.Token)
		r.Get("/me/installation", authHandler.Installation)
		r.Delete("/auth", authHandler.Disconnect)
	})

	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("listening on :%s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("shutdown: %v", err)
	}
}
