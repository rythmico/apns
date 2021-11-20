import APNSwift
import Logging
import NIO

public struct APNSwiftEnvironmentAgnosticConfiguration {
    public var authenticationMethod: APNSwiftConfiguration.AuthenticationMethod
    public var topic: String
    internal var logger: Logger?
    /// Optional timeout time if the connection does not receive a response.
    public var timeout: TimeAmount? = nil

    public init(
        authenticationMethod: APNSwiftConfiguration.AuthenticationMethod,
        topic: String,
        logger: Logger? = nil,
        timeout: TimeAmount? = nil
    ) {
        self.topic = topic
        self.authenticationMethod = authenticationMethod
        self.logger = logger
        self.timeout = timeout
    }
}

extension APNSwiftEnvironmentAgnosticConfiguration {
    public func fullConfiguration(with environment: APNSwiftConfiguration.Environment) -> APNSwiftConfiguration {
        APNSwiftConfiguration(
            authenticationMethod: authenticationMethod,
            topic: topic,
            environment: environment,
            logger: logger,
            timeout: timeout
        )
    }
}
