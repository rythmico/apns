import Vapor

extension Request {
    public var apns: APNS {
        .init(request: self)
    }

    public struct APNS {
        let request: Request
    }
}

extension Request.APNS {
    public var logger: Logger? {
        self.request.logger
    }

    public var eventLoop: EventLoop {
        self.request.eventLoop
    }

    public func client(_ environment: APNSwiftConfiguration.Environment) -> Application.APNS.Client {
        self.request.application.apns.client(environment, logger: logger, eventLoop: eventLoop)
    }
}
