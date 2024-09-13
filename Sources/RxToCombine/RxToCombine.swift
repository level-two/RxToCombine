import RxSwift
import Combine

public extension Observable {
    func toAnyPublisher() -> AnyPublisher<Element, Error> {
        RxWrappingPublisher(rxObservable: self).eraseToAnyPublisher()
    }
}

private struct RxWrappingPublisher<Output>: Publisher {
    typealias Failure = Error

    let rxObservable: Observable<Output>

    func receive(subscriber: some Subscriber<Output, Failure>) {
        let subscription = RxWrappingSubscription(rxObservable: rxObservable, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

private final class RxWrappingSubscription<S: Subscriber>: Subscription where S.Failure == Error {
    init(rxObservable: Observable<S.Input>, subscriber: S) {
        self.rxObservable = rxObservable
        self.subscriber = subscriber
    }

    func request(_ demand: Subscribers.Demand) {
        guard demand > .none, disposable == nil else { return }

        disposable = rxObservable?.subscribe(
            onNext: { [weak self] value in
                _ = self?.subscriber?.receive(value)
            },
            onError: { [weak self] error in
                self?.subscriber?.receive(completion: .failure(error))
                self?.cleanup()
            },
            onCompleted: { [weak self] in
                self?.subscriber?.receive(completion: .finished)
                self?.cleanup()
            }
        )
    }

    func cancel() {
        cleanup()
    }

    private func cleanup() {
        subscriber = nil
        disposable?.dispose()
        disposable = nil
        rxObservable = nil
    }

    private var rxObservable: Observable<S.Input>?
    private var disposable: Disposable?
    private var subscriber: S?
}
