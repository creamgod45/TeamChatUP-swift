//
//  UserManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import Combine

@MainActor
final class UserManager: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    
    private var allUsers: [User] = []
    private var currentPage = 1
    private var hasMorePages = true
    
    func loadUsers() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        AppLogger.shared.debug("載入使用者列表")
        
        do {
            let response = try await APIClient.shared.getUsers(page: 1, perPage: 50)
            self.allUsers = response.data
            self.users = response.data
            self.currentPage = 1
            self.hasMorePages = response.data.count >= 50
            
            AppLogger.shared.info("✅ 成功載入 \(response.data.count) 位使用者")
        } catch {
            let apiError = error as? APIError
            self.errorMessage = apiError?.errorDescription ?? "無法載入使用者列表: \(error.localizedDescription)"
            AppLogger.shared.error("載入使用者列表失敗", error: error)
        }
        
        isLoading = false
    }
    
    func searchUsers(query: String) async {
        searchQuery = query
        
        if query.isEmpty {
            users = allUsers
            AppLogger.shared.debug("清除搜尋，顯示所有使用者")
            return
        }
        
        isLoading = true
        AppLogger.shared.debug("搜尋使用者: \(query)")
        
        do {
            let response = try await APIClient.shared.getUsers(search: query, page: 1, perPage: 50)
            self.users = response.data
            AppLogger.shared.info("✅ 搜尋到 \(response.data.count) 位使用者")
        } catch {
            let apiError = error as? APIError
            self.errorMessage = apiError?.errorDescription ?? "搜尋失敗: \(error.localizedDescription)"
            AppLogger.shared.error("搜尋使用者失敗", error: error)
        }
        
        isLoading = false
    }
    
    func loadMoreUsers() async {
        guard !isLoading && hasMorePages else { return }
        
        isLoading = true
        let nextPage = currentPage + 1
        
        AppLogger.shared.debug("載入更多使用者 - 頁數: \(nextPage)")
        
        do {
            let response = try await APIClient.shared.getUsers(
                search: searchQuery.isEmpty ? nil : searchQuery,
                page: nextPage,
                perPage: 50
            )
            
            self.users.append(contentsOf: response.data)
            if searchQuery.isEmpty {
                self.allUsers.append(contentsOf: response.data)
            }
            self.currentPage = nextPage
            self.hasMorePages = response.data.count >= 50
            
            AppLogger.shared.info("✅ 載入了額外 \(response.data.count) 位使用者")
        } catch {
            AppLogger.shared.error("載入更多使用者失敗", error: error)
        }
        
        isLoading = false
    }
    
    func refreshUsers() async {
        AppLogger.shared.debug("重新整理使用者列表")
        await loadUsers()
    }
}
