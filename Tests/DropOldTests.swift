//
//  DropOldTests.swift
//  CombineExtTests
//
//  Created by Andrea Altea on 17/05/23.
//

import Foundation

#if !os(watchOS)
import XCTest
import Combine
import CombineExt

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class DropOldTests: XCTestCase {
    
    var subscriptions = Set<AnyCancellable>()
    
    override func tearDown() {
        subscriptions = Set()
    }
    
    func testUnlimitedDemand() {
        let subject1 = PassthroughSubject<Int, Never>()
        var completion: Subscribers.Completion<Never>?
        var values = [Int]()
        
        subject1
            .dropOld { $0 == $1 }
            .sink(receiveCompletion: { completion = $0 },
                  receiveValue: { values.append($0) })
            .store(in: &subscriptions)
        
        subject1.send(1)
        subject1.send(1)
        subject1.send(2)
        subject1.send(2)
        subject1.send(3)
        subject1.send(3)
        
        XCTAssertEqual(values, [1, 1, 2, 2, 3, 3])
        
        XCTAssertNil(completion)
        subject1.send(completion: .finished)
        XCTAssertEqual(completion, .finished)
    }
    
    func testOneItemDemand() {
        
        let subject1 = PassthroughSubject<Int, Never>()
        var lockingPublisher: CurrentValueSubject<Int, Never>?
        var completion: Subscribers.Completion<Never>?
        var values = [Int]()
        
        subject1
            .dropOld { $0 == $1 }
            .flatMap(maxPublishers: .max(1)) {
                lockingPublisher = CurrentValueSubject($0)
                return lockingPublisher!
            }
            .sink(receiveCompletion: { completion = $0 },
                  receiveValue: { values.append($0) })
            .store(in: &subscriptions)
        
        subject1.send(1)
        subject1.send(2)
        subject1.send(2)
        lockingPublisher?.send(completion: .finished)
        subject1.send(3)
        subject1.send(3)
        lockingPublisher?.send(completion: .finished)
        subject1.send(4)
        subject1.send(4)
        lockingPublisher?.send(completion: .finished)
        subject1.send(5)
        lockingPublisher?.send(completion: .finished)
        lockingPublisher?.send(completion: .finished)

        XCTAssertEqual(values, [1, 2, 3, 4, 5])
        
        XCTAssertNil(completion)
        subject1.send(completion: .finished)
        XCTAssertEqual(completion, .finished)
    }
}

#endif
