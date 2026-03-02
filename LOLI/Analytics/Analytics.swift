import TelemetryDeck

enum Analytics {
    static func setup() {
        let config = TelemetryDeck.Config(appID: "0C3C8113-F74F-4478-91B1-39BF8067EBE6")
        TelemetryDeck.initialize(config: config)
    }

    static func track(_ event: String, parameters: [String: String] = [:]) {
        TelemetryDeck.signal(event, parameters: parameters)
    }
}
