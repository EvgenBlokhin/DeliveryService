//
//  ProfileViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class ProfileViewModel {
    private let auth: AuthService
    // Outputs
    var onLogout: (() -> Void)?

    init(auth: AuthService) { self.auth = auth }

   

    func logoutTapped() async {
        await auth.logout()
        self.onLogout?()
    }
}
