//
//  AuthorizationViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.

import UIKit

final class AuthorizationViewModel {
    
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var password: String = ""
    var role: UserRole = .customer
    
    var onLoginSuccess: ((User) -> Void)?
    var onRegisterSuccess: ((User) -> Void)?
    var onLogout: (() -> Void)?
    var onError: ((String) -> Void)?
    
    private let auth: AuthService
    init(auth: AuthService) {
        self.auth = auth
        //self.delegate = self
        //delegate?.statusAutherization(false)
    }
    
    func canRegister() -> Bool { !name.isEmpty && !phone.isEmpty }
    func canLogin() -> Bool { !phone.isEmpty }
    
    func registerTapped() async {
        guard canRegister() else {
            onError?("Заполните имя и телефон")
            return
        }
        do {
            let register = try await auth.register(name: name, phone: phone, email: email, password: password, role: role.rawValue)
            self.onRegisterSuccess?(register)
        } catch {
            self.onError?("\(error)")
        }
    }
    
    func loginTapped() async {
        guard canLogin() else {
            onError?("Введите телефон")
            return
        }
        do {
            let user = try await auth.login(email: email , password: password)
            self.onLoginSuccess?(user)
        } catch {
            self.onError?("\(error)")
        }
    }
    func logout() async {
        await auth.logout()
        onLogout?()
    }
}
