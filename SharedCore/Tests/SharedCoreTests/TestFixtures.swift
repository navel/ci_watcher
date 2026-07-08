import Foundation

enum TestFixtures {
    /// RSA-2048 key generated for unit tests only — not used in production.
    static let rsaPrivateKeyPEM = """
    -----BEGIN PRIVATE KEY-----
    MIIEugIBADANBgkqhkiG9w0BAQEFAASCBKQwggSgAgEAAoIBAQCNjOg9E7ypydP1
    vOwMmJXiKW+A6kF4fotZTaXTQmJKd59WQXfi427lrF6BZx+HEPtYGAxXT3yvs2rs
    TE6+zsW7sQ2Ph2UC902phszLr616oD+9i1vakX9Fpqupi4VukoyIhdcL75NLXY6F
    6a7ZhkJGVh3ayryPMYn7r6EJ5n3UTxPQaKWregs1ESIgicmefXr2Q4uCj5S8HaGP
    OpvgxCCwl9NEcLRO4WqB03JI0whUwYfIf8Z19hTTVRgYPGiPzKzRPundq3iUqjPU
    CZVkeQob31RKJdBIk2GpMSoBW/RBy/i13lzGhhRbEcsyP8I+JXWEo1vmpqBzqvyC
    M6m4GKSbAgMBAAECgf9tYvbAPFW6NWjB/mfBVCkqcoWN73mozsyLtqBEdzMorkie
    ik6bMiarq7Ncoinltrna2hAEvj3HibSXPGDzaIG7Ce1GKDC8mgrqIcHMUMvpzOzK
    YrzDq1cvUXMBvVA1TWBMyyE5mBUQ/hD7FhszqQ04+FPEled2wPxgri3vTgTvNlwD
    1/zm8jmckgfWKAatwe7U5SFm1G4V3xKnFSFKT8+YItXTAoYqBM4I89wAN/Qwz8uy
    4vCRo+VwkoNIYY0dCrnhPLvEUBhDkKs98Bw74fMHd/jPSgFhtq/4imA9TT2mcQh2
    MY+2ihCyITLRjZkyiN7l2c0iSQciCIuxozuHYDECgYEAwV6xx5f1/FJgimrCVFL0
    /JwZMtjvsx8LLp5PyyIMWmIshPbM3QAbD6oBn0K7fyYAp5xI5ch8wby7WpFGhQi8
    +wwnj7v44vEGUwT3OL9o+qHP6ADQ1mFrYh+zzUcLMJzP1vdR13XZTNlURgaIQ9lS
    p3KH+cMx6w64tPVAaENranECgYEAu2WW8dC+Vw9h56DVOR70LxYFTNkfj1Zfq2pa
    mQ0U0CIPTlrH1qa2b3pRNMhPPLzAdkPq/5N9d6YPxekDCzfKPaALIMIYj0kRT0QK
    yfuONK+nCZSxvNzzt3r153j0DUAH+ORt3aUWUCcfWvdqLPpTeMC6gW4uaBMg2UPR
    DzR7jcsCgYBbj7Muh036xCbiY9rQgtduJZvo77/QWQq6cEvoK58dzQ63hwVKQBqQ
    ODe8aaTOd/gnZWE/LMemFO/B2rhBlfmmBgNVk/QtwWL1PIyzWi8jPitr97brTAXE
    2K4SrWknA5mGeGVQWIUkVmQJJF6xgd4ZW6n3Ie4pFzduuBJfTE04gQKBgDvgPdaN
    6ANROusTjI1vwn24/4CKb3cRFghjNwdoEppeB531i5yeL/R2lLPUvNyfQq+HC/MV
    YSV1vdxykzJmZQxDssqIueguZIV7LCdVZR6YcTqydAfwYT7i3udS0kfZibKQ6jnD
    odmCZpZeL2KnqTwP+IeaeOFwGzLQZGADWOb5AoGAa8HA+n/j8kLw86QLsq4HITKM
    BgalgD6VC25Wm/jhNH91l/3ATD17iyMpFBhLRNBp+xiPwWFl/VmOQDk67u+iQOUO
    m4eigKRanZNmCsjWz1fDW8LjDrQhVTInOwJmADpBwESI6lx+kC3bSN6aMbX98bth
    HpIdiMmZRr2ZJPH8m/4=
    -----END PRIVATE KEY-----
    """
    
    static let testAppID = "12345"
    static let testClientID = "Iv23liTESTCLIENTID"
    
    static var integrationTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["CIWATCHER_RUN_INTEGRATION_TESTS"] == "1"
    }
}
