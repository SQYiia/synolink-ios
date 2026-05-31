import Foundation
import Observation

@Observable
class AppStore {
    var servers: [ServerConfig] = []
    var accounts: [AccountConfig] = []
    var currentServerId: UUID?
    var currentAccountId: UUID?

    private let serversKey = "synolink.servers"
    private let accountsKey = "synolink.accounts"
    private let currentServerKey = "synolink.currentServerId"
    private let currentAccountKey = "synolink.currentAccountId"

    var currentServer: ServerConfig? { servers.first { $0.id == currentServerId } }
    var currentAccount: AccountConfig? { accounts.first { $0.id == currentAccountId } }

    func load() {
        if let data = UserDefaults.standard.data(forKey: serversKey),
           let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            servers = decoded
        }
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([AccountConfig].self, from: data) {
            accounts = decoded
        }
        if let str = UserDefaults.standard.string(forKey: currentServerKey), let uuid = UUID(uuidString: str) {
            currentServerId = uuid
        }
        if let str = UserDefaults.standard.string(forKey: currentAccountKey), let uuid = UUID(uuidString: str) {
            currentAccountId = uuid
        }
    }

    private func saveServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: serversKey)
        }
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    func addServer(_ server: ServerConfig) {
        servers.append(server)
        saveServers()
    }

    func removeServer(id: UUID) {
        servers.removeAll { $0.id == id }
        accounts.removeAll { $0.serverId == id }
        if currentServerId == id { currentServerId = nil; currentAccountId = nil }
        saveServers()
        saveAccounts()
    }

    func addAccount(_ account: AccountConfig) {
        accounts.append(account)
        saveAccounts()
    }

    func updateAccount(_ account: AccountConfig) {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
            saveAccounts()
        }
    }

    func setCurrent(serverId: UUID, accountId: UUID) {
        currentServerId = serverId
        currentAccountId = accountId
        UserDefaults.standard.set(serverId.uuidString, forKey: currentServerKey)
        UserDefaults.standard.set(accountId.uuidString, forKey: currentAccountKey)
    }

    func accountsForServer(_ serverId: UUID) -> [AccountConfig] {
        accounts.filter { $0.serverId == serverId }.sorted { ($0.lastLoginTime ?? .distantPast) > ($1.lastLoginTime ?? .distantPast) }
    }

    func logout() {
        currentServerId = nil
        currentAccountId = nil
        UserDefaults.standard.removeObject(forKey: currentServerKey)
        UserDefaults.standard.removeObject(forKey: currentAccountKey)
    }
}
