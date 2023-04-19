//
//  AnyPublisher.swift
//  CombineExt
//
//  Created by Andrea Altea on 19/04/23.
//  Copyright © 2020 Combine Community. All rights reserved.
//
#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension AnyPublisher {
    
    func sinkResult(_ completion: @escaping (Result<Output, Failure>) -> Void) -> AnyCancellable {
        self.materialize()
            .sink { event in
            switch event {
            case let .value(output):
                completion(.success(output))
                
            case let .failure(error):
                completion(.failure(error))
                
            case .finished:
                break
            }
        }
    }
}

#endif
