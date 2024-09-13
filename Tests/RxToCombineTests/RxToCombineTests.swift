@testable import RxToCombine
import XCTest
import Combine
import RxSwift

class ObservableToAnyPublisherTests: XCTestCase {
    var disposeBag = DisposeBag()
    var cancellables = Set<AnyCancellable>()

    func testNormalOperation() {
        let expectation = XCTestExpectation(description: "Normal operation")
        let valueExpectation = XCTestExpectation(description: "Received value")
        let observable = Observable.just(1)
        let publisher = observable.toAnyPublisher()

        publisher.sink(
            receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Unexpected failure")
                }
            },
            receiveValue: { value in
                XCTAssertEqual(value, 1)
                valueExpectation.fulfill()
                expectation.fulfill()
            }
        ).store(in: &cancellables)

        wait(for: [expectation, valueExpectation], timeout: 1.0)
    }

    func testRxObservableNormalTermination() {
        let expectation = XCTestExpectation(description: "Rx Observable normal termination")
        let observable = Observable.just(1)
        let publisher = observable.toAnyPublisher()

        publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    expectation.fulfill()
                case .failure:
                    XCTFail("Unexpected failure")
                }
            },
            receiveValue: { _ in }
        ).store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testRxObservableAbnormalTermination() {
        let expectation = XCTestExpectation(description: "Rx Observable abnormal termination")
        let observable = Observable<Int>.error(TestError.test)
        let publisher = observable.toAnyPublisher()

        publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Unexpected completion")
                case .failure(let error):
                    XCTAssertEqual(error as? TestError, TestError.test)
                    expectation.fulfill()
                }
            },
            receiveValue: { _ in
                XCTFail("Unexpected value reception")
            }
        ).store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testRxObservableDelayedTermination() {
        let expectation = XCTestExpectation(description: "Rx Observable delayed termination")
        let valueExpectation = XCTestExpectation(description: "Received value")
        let observable = Observable.just(1).delay(.seconds(1), scheduler: MainScheduler.instance)
        let publisher = observable.toAnyPublisher()

        publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    expectation.fulfill()
                case .failure:
                    XCTFail("Unexpected failure")
                }
            },
            receiveValue: { value in
                XCTAssertEqual(value, 1)
                valueExpectation.fulfill()
            }
        ).store(in: &cancellables)

        wait(for: [expectation, valueExpectation], timeout: 2.0)
    }

    func testRxObservableAbnormalDelayedTermination() {
        let expectation = XCTestExpectation(description: "Rx Observable abnormal delayed termination")
        let observable = Observable<Int>.create { observer in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                observer.onError(TestError.test)
            }
            return Disposables.create()
        }
        let publisher = observable.toAnyPublisher()

        publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Unexpected completion")
                case .failure(let error):
                    XCTAssertEqual(error as? TestError, TestError.test)
                    expectation.fulfill()
                }
            },
            receiveValue: { _ in
                XCTFail("Unexpected value reception")
            }
        ).store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
    }

    func testCombineChainNormalTermination() {
        let expectation = XCTestExpectation(description: "Combine chain normal termination")
        let valueExpectation = XCTestExpectation(description: "Received value")
        let observable = Observable.just(1)
        let publisher = observable.toAnyPublisher()

        publisher
            .map { $0 * 2 }
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        expectation.fulfill()
                    case .failure:
                        XCTFail("Unexpected failure")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, 2)
                    valueExpectation.fulfill()
                }
            ).store(in: &cancellables)

        wait(for: [expectation, valueExpectation], timeout: 1.0)
    }

    func testCombineChainAbnormalTermination() {
        let expectation = XCTestExpectation(description: "Combine chain abnormal termination")
        let observable = Observable.just(1)
        let publisher = observable.toAnyPublisher()

        publisher
            .tryMap { _ in throw TestError.test }
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Unexpected completion")
                    case .failure(let error):
                        XCTAssertEqual(error as? TestError, TestError.test)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Unexpected value reception")
                }
            ).store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testCombineChainDelayedValue() {
        let expectation = XCTestExpectation(description: "Combine chain delayed value")
        let valueExpectation = XCTestExpectation(description: "Received value")
        let observable = Observable.just(1).delay(.seconds(1), scheduler: MainScheduler.instance)
        let publisher = observable.toAnyPublisher()

        publisher
            .map { $0 * 2 }
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        expectation.fulfill()
                    case .failure:
                        XCTFail("Unexpected failure")
                    }
                },
                receiveValue: { value in
                    XCTAssertEqual(value, 2)
                    valueExpectation.fulfill()
                }
            ).store(in: &cancellables)

        wait(for: [expectation, valueExpectation], timeout: 2.0)
    }

    func testCombineChainDelayedFailure() {
        let expectation = XCTestExpectation(description: "Combine chain delayed failure")
        let observable = Observable<Int>.error(TestError.test).delay(.seconds(1), scheduler: MainScheduler.instance)
        let publisher = observable.toAnyPublisher()

        publisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Unexpected completion")
                    case .failure(let error):
                        XCTAssertEqual(error as? TestError, TestError.test)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Unexpected value reception")
                }
            ).store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
    }

    func testCombineChainSubscriptionTermination() {
        let expectation = XCTestExpectation(description: "Combine chain subscription termination")
        let observable = Observable.just(1).delay(.seconds(2), scheduler: MainScheduler.instance)
        let publisher = observable.toAnyPublisher()
        var cancellable: AnyCancellable?

        cancellable = publisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        // In short, receiveCompletion is designed to handle the natural end of the publisher's lifecycle
                        // (either successful completion or an error), while cancellable.cancel() is an external intervention
                        // that stops the subscription immediately without triggering the receiveCompletion closure.
                        XCTFail("Unexpected finishing")
                    case .failure:
                        XCTFail("Unexpected failure")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Unexpected value reception")
                }
            )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            cancellable?.cancel()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    enum TestError: Error, Equatable {
        case test
    }
}
