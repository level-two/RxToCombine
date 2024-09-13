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

    func testObservableWithMultipleValues() {
        let expectation = XCTestExpectation(description: "Received all values")
        let values = [1, 2, 3]
        let observable = Observable.from(values).delay(.milliseconds(100), scheduler: MainScheduler.instance)
        let publisher = observable.toAnyPublisher()
        var receivedValues = [Int]()

        publisher.sink(
            receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Unexpected failure")
                } else {
                    XCTAssertEqual(receivedValues, values)
                    expectation.fulfill()
                }
            },
            receiveValue: { value in
                receivedValues.append(value)
            }
        ).store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testObservableWithMultipleValuesAndCancellation() {
        let expectation = XCTestExpectation(description: "Received values before cancellation")
        let values = [1, 2, 3]
        let observable = Observable.from(values).concatMap { value in
            Observable.just(value).delay(.milliseconds(200), scheduler: MainScheduler.instance)
        }
        let publisher = observable.toAnyPublisher()
        var receivedValues = [Int]()

        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Unexpected failure")
                }
            },
            receiveValue: { value in
                receivedValues.append(value)
            }
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.600) {
            cancellable.cancel()
            XCTAssertEqual(receivedValues, [1, 2])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
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

    func testMultipleSubscriptions() {
        let expectation1 = XCTestExpectation(description: "First subscription completion")
        let expectation2 = XCTestExpectation(description: "Second subscription completion")
        let expectation3 = XCTestExpectation(description: "Third subscription completion")

        let observable = Observable.just(1).delay(.seconds(2), scheduler: MainScheduler.instance)
        let publisher = observable.toAnyPublisher()
        let cancellable1: AnyCancellable
        let cancellable2: AnyCancellable
        let cancellable3: AnyCancellable

        cancellable1 = publisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Unexpected failure in first subscription")
                    }
                },
                receiveValue: { value in
                    if value == 1 {
                        expectation1.fulfill()
                    }
                }
            )

        cancellable2 = publisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Unexpected failure in second subscription")
                    }
                },
                receiveValue: { value in
                    if value == 1 {
                        expectation2.fulfill()
                    }
                }
            )

        cancellable3 = publisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Unexpected finishing in third subscription")
                    case .failure:
                        XCTFail("Unexpected failure in third subscription")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Unexpected value reception in third subscription")
                }
            )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            cancellable3.cancel()
            expectation3.fulfill()
        }

        wait(for: [expectation1, expectation2, expectation3], timeout: 2.0)
    }

    func testMultipleSubscriptionsWithError() {
        let expectation1 = XCTestExpectation(description: "First subscription completion")
        let expectation2 = XCTestExpectation(description: "Second subscription completion")
        let expectation3 = XCTestExpectation(description: "Third subscription completion")

        let observable = Observable<Int>
            .create { observer in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    observer.onError(TestError.test)
                }
                return Disposables.create()
            }
            .delay(.seconds(2), scheduler: MainScheduler.instance)

        let publisher = observable.toAnyPublisher()
        let cancellable1: AnyCancellable
        let cancellable2: AnyCancellable
        let cancellable3: AnyCancellable

        cancellable1 = publisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Unexpected finishing in first subscription")
                    case .failure(let error):
                        XCTAssertEqual(error as? TestError, TestError.test)
                        expectation1.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Unexpected value reception in first subscription")
                }
            )

        cancellable2 = publisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Unexpected finishing in second subscription")
                    case .failure(let error):
                        XCTAssertEqual(error as? TestError, TestError.test)
                        expectation2.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Unexpected value reception in second subscription")
                }
            )

        cancellable3 = publisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Unexpected finishing in third subscription")
                    case .failure(let error):
                        XCTAssertEqual(error as? TestError, TestError.test)
                        expectation3.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Unexpected value reception in third subscription")
                }
            )

        wait(for: [expectation1, expectation2, expectation3], timeout: 3.0)
    }

    func testObservableDisposedOnPublisherCancel() {
        let expectation = self.expectation(description: "Observable should be disposed")
        var isDisposed = false

        let observable = Observable<Void>.create { observer in
            return Disposables.create {
                isDisposed = true
                expectation.fulfill()
            }
        }

        let publisher = observable.toAnyPublisher()
        let cancellable = publisher
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        cancellable.cancel()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(isDisposed, "Observable was not disposed when publisher was cancelled")
    }

    enum TestError: Error, Equatable {
        case test
    }
}
