//  PublisherTests.swift
//  CombineExt
//
//  Created by Andrea Altea on 19/04/2023.
//  Copyright © 2020 Combine Community. All rights reserved.
//
#if !os(watchOS)
import Combine
import CombineExt
import XCTest

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class PublisherTests: XCTestCase {
    private var subscription: AnyCancellable?
    
    func testSinkResultValue() {
        var results = [Int]()
        var completion: Subscribers.Completion<Never>?
        let subject = PassthroughSubject<Int, Never>()
        
        subscription = subject
            .handleEvents(receiveCompletion: {
                completion = $0
            })
            .sinkResult { result in
                switch result {
                case .success(let value):
                    results.append(value)
                case .failure:
                    XCTAssert(true)
                }
            }
        
        subject.send(1)
        subject.send(3)
        subject.send(4)
        subject.send(2)
        subject.send(completion: .finished)
        
        XCTAssertEqual([1, 3, 4, 2], results)
        XCTAssertEqual(.finished, completion)
    }
    
    func testSinkResultError() {
        var results = [Int]()
        var completion: Subscribers.Completion<NSError>?
        let subject = PassthroughSubject<Int, NSError>()
        let error = NSError(domain: "Invalid", code: 200)
        
        subscription = subject
            .sinkResult { result in
                switch result {
                case .success(let value):
                    results.append(value)
                case .failure(let error):
                    completion = .failure(error)
                }
            }
        
        subject.send(completion: .failure(error))
        
        XCTAssertEqual([], results)
        XCTAssertEqual(completion, .failure(error))
    }
}

#endif
