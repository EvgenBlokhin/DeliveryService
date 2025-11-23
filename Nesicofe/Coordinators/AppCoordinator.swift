//
//  AppCoordinator.swift
//  Nesicofe
//
//  Created by dev on 25/08/2025.
//
import UIKit

protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    func start() async
}
@MainActor
final class AppCoordinator: @preconcurrency Coordinator {
    
    var navigationController = UINavigationController()
    private let window: UIWindow
    
    private let authService: AuthService
    private let cartService: CartService
    private let locationService: UserLocationService
    private let transport: HTTPTransport
    private let keychainHelper: KeychainHelper
    private let authRemote: AuthRemoteDataSource
    private let networkClient: NetworkClient
    private let coreDataStorage: CoreDataStorage
    private let mapService: MapService
    private let orderService: OrderService
    private let bufferStorage: CoreDataBufferStorage
    private let webSocketService: WebSocketService
    private let chatService: ChatService
    
    private let tabBarController = UITabBarController()
    
    init(window: UIWindow) {
        self.window = window
        
        self.transport = HTTPTransport()
        self.keychainHelper = KeychainHelper()
        self.authRemote = AuthRemoteDataSource(transport: self.transport)
        self.authService = AuthService(remote: self.authRemote, keychain: self.keychainHelper)
        self.networkClient = NetworkClient(transport: self.transport, authService: self.authService)
        self.coreDataStorage = CoreDataStorage()
        self.cartService = CartService()
        self.locationService = UserLocationService(authService: self.authService)
        self.mapService = MapService(client: self.networkClient)
        self.orderService = OrderService(client: self.networkClient, coreData: self.coreDataStorage)
        self.bufferStorage = CoreDataBufferStorage(core: self.coreDataStorage)
        self.webSocketService = WebSocketService(authService: self.authService, orderService: self.orderService, keyChain: self.keychainHelper, bufferStorage: self.bufferStorage)
        self.orderService.setWebSocket(self.webSocketService)
        self.mapService.setWebSocket(self.webSocketService)
        self.chatService = ChatService(wsService: self.webSocketService, bufferStorage: self.bufferStorage, coreData: self.coreDataStorage )
        
        self.start()
    }
    
    func start() {
        setupCoordinators()
        createChatCoordinator()
        maybyConnectWebSocket()
    }
    
    private func setupCoordinators() {
        // Map
        let mapNavigation = navigationController
        let mapCoordinator = MapCoordinator(navigation: mapNavigation, tabBar: tabBarController, map: mapService, cart: cartService, chat: chatService, orders: orderService, location: locationService, webSocket: webSocketService )
        mapCoordinator.start()
        
        // Orders
        let ordersNavigation = navigationController
        let ordersCoordinator = OrdersCoordinator(nav: ordersNavigation, orders: orderService, storage: coreDataStorage, webSocket: webSocketService, chatService: chatService)
        ordersCoordinator.start()
        
        // Cart
        let cartNavigation = navigationController
        let cartCoordinator = CartCoordinator(nav: cartNavigation, auth: authService, cart: cartService, chat: chatService, orders: orderService, addressProvider: locationService, webSocket: webSocketService)
        cartCoordinator.start()
        
        // Profile
        let profileNavigation = navigationController
        let profileCoordinator = ProfileCoordinator(nav: profileNavigation, auth: authService)
        profileCoordinator.start()
        
        mapNavigation.tabBarItem = UITabBarItem(title: "Карта", image: UIImage(systemName: "map"), tag: 0)
        ordersNavigation.tabBarItem = UITabBarItem(title: "Заказы", image: UIImage(systemName: "list.bullet.rectangle"), tag: 1)
        cartNavigation.tabBarItem = UITabBarItem(title: "Корзина", image: UIImage(systemName: "cart"), tag: 2)
        profileNavigation.tabBarItem = UITabBarItem(title: "Профиль", image: UIImage(systemName: "person.crop.circle"), tag: 3)
        
        let viewControllers = [mapNavigation, ordersNavigation, cartNavigation, profileNavigation]
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
    
    private func createChatCoordinator() {
        webSocketService.onCourierAccepted = { [weak self] order in
            guard let self, let orderId = order.id else { return }
            let chatCoord = ChatCoordinator(navigationController: self.navigationController, service: chatService, webSocket: webSocketService, orderId: orderId, userId: order.userId)
        }
    }
    
    private func maybyConnectWebSocket() {
        authService.isAuthenticated = { [weak self] value in
            guard let self = self else { return }
            switch value {
            case true: self.webSocketService.connect()
            case false: self.webSocketService.disconnect()
            }
        }
    }
}


//        private func handleOrderAccepted(orderId: String, courierId: String) async {
//            do {
//                // Получить детали ордера из сервиса или обновить локально
//                if var order = try await ordersService.getMyOrders() {
//                    order.courierId = courierId
//                    order.status = "accepted"
//                    storage.save([order], key: "orders_history")  // упрощённо — merge
//                    // Можно уведомить контроллер заказов / карту об изменении
//                }
//            } catch {
//                print("Error fetch order detail on accept:", error)
//            }
//        }
    
    

