//
//  DropOld.swift
//  CombineExt
//
//  Created by Andrea Altea on 14/05/23.
//

#if canImport(Combine)

import Combine
import Foundation

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher {
    
    func dropOld(_ shouldDrop: @escaping (Self.Output, Self.Output) -> Bool) -> Publishers.DropOld<Self> {
        Publishers.DropOld(upstream: self, shouldDrop: shouldDrop)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publishers {
    class DropOld<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        private let shouldDrop: (_ old: Output, _ new: Output) -> Bool
        
        init(upstream: Upstream, shouldDrop: @escaping (_ old: Output, _ new: Output) -> Bool) {
            self.upstream = upstream
            self.shouldDrop = shouldDrop
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Upstream.Failure == S.Failure, Upstream.Output == S.Input {
            subscriber.receive(subscription: Subscription(upstream: upstream,
                                                          downstream: subscriber,
                                                          shouldDrop: shouldDrop))
        }
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publishers.DropOld {
    class Subscription<Downstream: Subscriber>: Combine.Subscription where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure {
        
        private let upstream: Upstream
        private let downstream: Downstream
        private var sink: Sink<Downstream>?
        
        init(upstream: Upstream, downstream: Downstream, shouldDrop: @escaping (_ old: Output, _ new: Output) -> Bool) {
            self.upstream = upstream
            self.downstream = downstream
            self.sink = Sink(upstream: upstream, downstream: downstream, shouldDrop: shouldDrop)
        }
        
        func request(_ demand: Subscribers.Demand) {
            sink?.demand(demand)
        }
        
        func cancel() {
            sink = nil
        }
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publishers.DropOld {
    class Sink<Downstream: Subscriber>: CombineExt.Sink<Upstream, Downstream> where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure {
        
        private let lock = NSRecursiveLock()
        private var myUpstreamSubscription: Combine.Subscription?
        private let shouldDrop: (_ old: Output, _ new: Output) -> Bool
        private var oldValue: Output?
        
        private var downstreamDemand = Subscribers.Demand.none
        
        init(upstream: Upstream, downstream: Downstream, shouldDrop: @escaping (_ old: Output, _ new: Output) -> Bool) {
            
            self.shouldDrop = shouldDrop
            super.init(upstream: upstream, downstream: downstream)
        }

        override func receive(subscription: Combine.Subscription) {
            super.receive(subscription: subscription)
            myUpstreamSubscription = subscription
        }
        
        override func demand(_ demand: Subscribers.Demand) {
            
            lock.lock()
            defer { lock.unlock() }

            downstreamDemand += buffer.demand(demand)
            if let oldValue = oldValue {
                self.oldValue = nil
                sendToDownstream(oldValue)
            }
            myUpstreamSubscription?.requestIfNeeded(.max(1))
        }

        override func receive(_ input: Output) -> Subscribers.Demand {
            
            lock.lock()
            defer { lock.unlock() }

            if downstreamDemand > .none {
                return openDownstream(input)
            }
            
            return closedDownstream(input)
        }

        private func openDownstream(_ input: Output) -> Subscribers.Demand {

            guard let oldValue = self.oldValue else {
                return sendToDownstream(input)
            }

            if shouldDrop(oldValue, input) {
                self.oldValue = nil
                return sendToDownstream(input)
            }
            
            self.oldValue = input
            return sendToDownstream(oldValue)
        }
        
        private func closedDownstream(_ input: Output) -> Subscribers.Demand {

            defer {
                self.oldValue = input
            }

            guard let oldValue = oldValue,
                    !shouldDrop(oldValue, input) else {
                return .max(1)
            }
            return sendToDownstream(oldValue)
        }
        
        private func resendOldValue() -> Subscribers.Demand {
            
            if let oldValue = oldValue {
                return receive(oldValue)
            }
            return .max(1)
        }
        
        @discardableResult
        private func sendToDownstream(_ input: Output) -> Subscribers.Demand {
            
            if downstreamDemand > .none { downstreamDemand -= 1 }
            downstreamDemand += buffer.buffer(value: input)
            return .max(1)
        }
    }
}


#endif
