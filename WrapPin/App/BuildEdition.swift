enum BuildEdition {
#if WRAPPIN_TUNNEL_EDITION
    static let supportsBuiltInTunnel = true
#else
    static let supportsBuiltInTunnel = false
#endif
}
