import VDStore
import Foundation

struct DataManager: Sendable {
  var load: @Sendable (_ from: URL) async throws -> Data
  var save: @Sendable (Data, _ to: URL) async throws -> Void
}

extension DataManager {
  static let liveValue = Self(
    load: { url in try Data(contentsOf: url) },
    save: { data, url in try data.write(to: url) }
  )

    static let testValue = Self { _ in
        Data()
    } save: { _, _ in
    }
}

extension StoreDIValues {

  @StoreDIValue
  var dataManager: DataManager = valueFor(live: DataManager.liveValue, test: DataManager.testValue)
}

extension DataManager {

  static func mock(initialData: Data? = nil) -> Self {
    let data = ActorIsolated(initialData)
    return Self(
      load: { _ in
          guard let data = await data.value
        else {
          struct FileNotFound: Error {}
          throw FileNotFound()
        }
        return data
      },
      save: { newData, _ in await data.set(newData) }
    )
  }

  static let failToWrite = Self(
    load: { _ in Data() },
    save: { _, _ in
      struct SaveError: Error {}
      throw SaveError()
    }
  )

  static let failToLoad = Self(
    load: { _ in
      struct LoadError: Error {}
      throw LoadError()
    },
    save: { _, _ in }
  )
}
