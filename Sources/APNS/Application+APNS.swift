import Vapor
import APNSwift

extension Application {
    public var apns: APNS {
        .init(application: self)
    }

    public struct APNS {
        struct ConfigurationKey: StorageKey {
            typealias Value = APNSwiftEnvironmentAgnosticConfiguration
        }

        public var configuration: APNSwiftEnvironmentAgnosticConfiguration? {
            get {
                self.application.storage[ConfigurationKey.self]
            }
            nonmutating set {
                self.application.storage[ConfigurationKey.self] = newValue
            }
        }

        struct SandboxPoolKey: StorageKey, LockKey {
            typealias Value = EventLoopGroupConnectionPool<APNSConnectionSource>
        }

        struct ProductionPoolKey: StorageKey, LockKey {
            typealias Value = EventLoopGroupConnectionPool<APNSConnectionSource>
        }

        public func pool<Key>(_ key: Key.Type) -> EventLoopGroupConnectionPool<APNSConnectionSource> where Key: StorageKey, Key: LockKey, Key.Value == EventLoopGroupConnectionPool<APNSConnectionSource> {
            if let existing = self.application.storage[key] {
                return existing
            } else {
                let lock = self.application.locks.lock(for: key)
                lock.lock()
                defer { lock.unlock() }
                guard let configuration = self.configuration else {
                    fatalError("APNS not configured. Use app.apns.configuration = ...")
                }
                let new = EventLoopGroupConnectionPool(
                    source: APNSConnectionSource(
                        configuration: configuration.fullConfiguration(
                            with: environment(for: key)
                        )
                    ),
                    maxConnectionsPerEventLoop: 1,
                    logger: self.application.logger,
                    on: self.application.eventLoopGroup
                )
                self.application.storage.set(key, to: new) {
                    $0.shutdown()
                }
                return new
            }
        }

        func environment<Key>(for key: Key.Type) -> APNSwiftConfiguration.Environment where Key: StorageKey, Key: LockKey, Key.Value == EventLoopGroupConnectionPool<APNSConnectionSource> {
            if key == SandboxPoolKey.self {
                return .sandbox
            } else if key == ProductionPoolKey.self {
                return .production
            } else {
                fatalError("Invalid APNSConnectionSource pool key: \(key)")
            }
        }

        let application: Application
    }
}

extension Application.APNS {
    public var logger: Logger? {
        self.application.logger
    }

    public var eventLoop: EventLoop {
        self.application.eventLoopGroup.next()
    }

    public func client(_ environment: APNSwiftConfiguration.Environment) -> Client {
        Client(application: application, logger: logger, eventLoop: eventLoop, environment: environment)
    }

    func client(_ environment: APNSwiftConfiguration.Environment, logger: Logger?, eventLoop: EventLoop) -> Client {
        Client(application: application, logger: logger, eventLoop: eventLoop, environment: environment)
    }
}

extension Application.APNS {
    public struct Client: APNSwiftClient {
        public let application: Application
        public let logger: Logger?
        public let eventLoop: EventLoop
        public let environment: APNSwiftConfiguration.Environment

        public var pool: EventLoopGroupConnectionPool<APNSConnectionSource> {
            switch environment {
            case .sandbox:
                return self.application.apns.pool(SandboxPoolKey.self)
            case .production:
                return self.application.apns.pool(ProductionPoolKey.self)
            }
        }

        public func send(
            rawBytes payload: ByteBuffer,
            pushType: APNSwiftConnection.PushType,
            to deviceToken: String,
            expiration: Date?,
            priority: Int?,
            collapseIdentifier: String?,
            topic: String?,
            logger: Logger?,
            apnsID: UUID? = nil
        ) -> EventLoopFuture<Void> {
            self.pool.withConnection(
                logger: logger ?? self.logger,
                on: self.eventLoop
            ) {
                $0.send(
                    rawBytes: payload,
                    pushType: pushType,
                    to: deviceToken,
                    expiration: expiration,
                    priority: priority,
                    collapseIdentifier: collapseIdentifier,
                    topic: topic,
                    logger: logger ?? self.logger,
                    apnsID: apnsID
                )
            }
        }
    }
}
