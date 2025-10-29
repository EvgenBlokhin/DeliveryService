//
//  AppCoordinator.swift
//  Nesicofe
//
//  Created by dev on 25/08/2025.
//
import UIKit

final class AppCoordinator {
    let navigationController = UINavigationController()
    private let window: UIWindow

    // Dependencies
    private let authService: AuthService
    private let cartService: CartService
    private let locationService: LocationService
    private let transport: HTTPTransport
    private let keychainHelper: KeychainHelper
    private let authRemote: AuthRemoteDataSource
    private let networkClient: NetworkClient
    private let mapService: MapService
    private let ordersService: OrdersService
    private let webSocket: WebSocketService
    private let chatService: ChatService
    private let simpleStorage: SimpleStorage

    // Tabs
    private let tabBarController = UITabBarController()
    

    // Child coordinators
    private var mapCoord: MapCoordinator?
    private var ordersCoord: OrdersCoordinator?
    private var cartCoord: CartCoordinator?
    private var profileCoord: ProfileCoordinator?

    init(window: UIWindow) async {
        self.window = window
        
        // core deps
            self.transport = HTTPTransport()
            self.keychainHelper = KeychainHelper()
            self.authRemote = AuthRemoteDataSource(transport: self.transport)

            // auth must be initialized before networkClient if refreshClosure uses authService
            let auth = AuthService(remote: self.authRemote, keychain: self.keychainHelper)
            self.authService = auth
        
            // network client with refresh closure that uses authService
            self.networkClient = NetworkClient(transport: self.transport, authService: self.authService)

            // other services
            self.cartService = CartService()
            self.locationService = LocationService()
            self.mapService = MapService(client: self.networkClient)
            self.ordersService = OrdersService(client: self.networkClient)
            self.webSocket = WebSocketService()
            self.chatService = ChatService(wsClient: self.webSocket)
            self.simpleStorage = SimpleStorage()
    }

     func start() {
        // Map
        let mapNav = UINavigationController()
        mapNav.navigationBar.isTranslucent = false
         let mapCoord = MapCoordinator(navigation: mapNav, tabBar: tabBarController, map: mapService, cart: cartService, chat: chatService, orders: ordersService, location: locationService, webSocket: webSocket )
        mapCoord.start()

        // Orders
        let ordersNav = UINavigationController()
        mapNav.navigationBar.isTranslucent = false
         let ordersCoord = OrdersCoordinator(nav: ordersNav, orders: ordersService, storage: simpleStorage, webSocket: webSocket)
        ordersCoord.start()

        // Cart
        let cartNav = UINavigationController()
        mapNav.navigationBar.isTranslucent = false
         let cartCoord = CartCoordinator(nav: cartNav, auth: authService, cart: cartService, orders: ordersService, addressProvider: locationService)
        cartCoord.start()

        // Profile
        let profileNav = UINavigationController()
        mapNav.navigationBar.isTranslucent = false
        let profileCoord = ProfileCoordinator(nav: profileNav, auth: authService)
        profileCoord.start()

        self.mapCoord = mapCoord
        self.ordersCoord = ordersCoord
        self.cartCoord = cartCoord
        self.profileCoord = profileCoord

        mapNav.tabBarItem = UITabBarItem(title: "Карта", image: UIImage(systemName: "map"), tag: 0)
        ordersNav.tabBarItem = UITabBarItem(title: "Заказы", image: UIImage(systemName: "list.bullet.rectangle"), tag: 1)
        cartNav.tabBarItem = UITabBarItem(title: "Корзина", image: UIImage(systemName: "cart"), tag: 2)
        profileNav.tabBarItem = UITabBarItem(title: "Профиль", image: UIImage(systemName: "person.crop.circle"), tag: 3)

        let viewControllers = [mapNav, ordersNav, cartNav, profileNav]
        for navController in viewControllers {
                navController.navigationBar.isTranslucent = false
                navController.edgesForExtendedLayout = .all
                navController.extendedLayoutIncludesOpaqueBars = true
            }
        tabBarController.viewControllers = viewControllers
        tabBarController.selectedIndex = 0
        tabBarController.view.backgroundColor = .systemBackground
        tabBarController.tabBar.tintColor = .blue
        // Важно: разрешить расширение под tab bar
        tabBarController.edgesForExtendedLayout = .all
        tabBarController.extendedLayoutIncludesOpaqueBars = true
        tabBarController.tabBar.isTranslucent = false

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
         
    }

        private func handleOrderAccepted(orderId: String, courierId: String) async {
            do {
                // Получить детали ордера из сервиса или обновить локально
                if var order = try await ordersService.getMyOrders() {
                    order.courierId = courierId
                    order.status = "accepted"
                    storage.save([order], key: "orders_history")  // упрощённо — merge
                    // Можно уведомить контроллер заказов / карту об изменении
                }
            } catch {
                print("Error fetch order detail on accept:", error)
            }
        }
    
    
}
