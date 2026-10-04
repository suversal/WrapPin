enum BuildEdition {
#if WRAPPIN_TUNNEL_EDITION
    static let supportsBuiltInTunnel = true
    static let callbackScheme = "wrappintunnel"
#else
    static let supportsBuiltInTunnel = false
    static let callbackScheme = "wrappin"
#endif
}
