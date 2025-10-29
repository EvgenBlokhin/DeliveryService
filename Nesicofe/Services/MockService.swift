//
//  MockService.swift
//  Nesicofe
//
//  Created by dev on 29/09/2025.
//

//final class MockService {
//    private(set) var list: [MachineModel] = []
//
//    init() {
//        list = [
//            MachineModel(
//                id: 1,
//                title: "Гончарова 5",
//                imageName: "machine",
//                coordinate: .init(54.3091, 48.3740),
//                menu: [
//                    DrinkModel(id: 1, name: "Эспрессо", price: 80, imageName: "espresso"),
//                    DrinkModel(id: 2, name: "Американо", price: 90, imageName: "americano")
//                ]
//            ),
//            MachineModel(
//                id: 2,
//                title: "Гончарова 12",
//                imageName: "machine",
//                coordinate: .init(54.3085, 48.3719),
//                menu: [
//                    DrinkModel(id: 3, name: "Капучино", price: 120, imageName: "capp"),
//                    DrinkModel(id: 4, name: "Латте", price: 130, imageName: "latte"),
//                    DrinkModel(id: 5, name: "Эспрессо", price: 80, imageName: "espresso"),
//                    DrinkModel(id: 6, name: "Американо", price: 90, imageName: "americano")
//                ]
//            ),
//            MachineModel(
//                id: 3,
//                title: "Пушкина 5",
//                imageName: "machine",
//                coordinate: .init(54.3100, 48.3795),
//                menu: [
//                    DrinkModel(id: 7, name: "Капучино", price: 120, imageName: "capp"),
//                    DrinkModel(id: 8, name: "Латте", price: 130, imageName: "latte"),
//                    DrinkModel(id: 9, name: "Эспрессо", price: 80, imageName: "espresso"),
//                    DrinkModel(id: 10, name: "Американо", price: 90, imageName: "americano"),
//                    DrinkModel(id: 11, name: "Моккачино", price: 140, imageName: "mocha"),
//                    DrinkModel(id: 12, name: "Раф", price: 150, imageName: "raf")
//                ]
//            ),
//            MachineModel(
//                id: 4,
//                title: "Ленина 22",
//                imageName: "machine",
//                coordinate: .init(54.3123, 48.3720),
//                menu: [
//                    DrinkModel(id: 13, name: "Эспрессо", price: 80, imageName: "espresso"),
//                    DrinkModel(id: 14, name: "Американо", price: 90, imageName: "americano"),
//                    DrinkModel(id: 15, name: "Флэт Уайт", price: 160, imageName: "flatwhite"),
//                    DrinkModel(id: 16, name: "Гляссе", price: 170, imageName: "glace")
//                ]
//            ),
//            MachineModel(
//                id: 5,
//                title: "Спасская 8",
//                imageName: "machine",
//                coordinate: .init(54.3070, 48.3780),
//                menu: [
//                    DrinkModel(id: 17, name: "Латте", price: 130, imageName: "latte"),
//                    DrinkModel(id: 18, name: "Флэт Уайт", price: 160, imageName: "flatwhite"),
//                    DrinkModel(id: 19, name: "Гляссе", price: 170, imageName: "glace"),
//                    DrinkModel(id: 20, name: "Макиато", price: 100, imageName: "macchiato"),
//                    DrinkModel(id: 21, name: "Фраппе", price: 180, imageName: "frappe")
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Рябикова 70",
//                imageName: "machine",
//                coordinate: .init(54.276284, 48.289935),
//                menu: [
//                    DrinkModel(id: 22, name: "Эспрессо", price: 80, imageName: "espresso"),
//                    DrinkModel(id: 23, name: "Американо", price: 90, imageName: "americano"),
//                    DrinkModel(id: 24, name: "Кортадо", price: 110, imageName: "cortado"),
//                    DrinkModel(id: 25, name: "Айриш", price: 200, imageName: "irish"),
//                    DrinkModel(id: 26, name: "Латте", price: 130, imageName: "latte"),
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Нариманова 3",
//                imageName: "machine",
//                coordinate: .init(54.340864, 48.379641),
//                menu: [
//                    DrinkModel(id: 27, name: "Кортадо", price: 110, imageName: "cortado"),
//                    DrinkModel(id: 28, name: "Айриш", price: 200, imageName: "irish"),
//                    DrinkModel(id: 29, name: "Американо", price: 90, imageName: "americano"),
//                    DrinkModel(id: 30, name: "Моккачино", price: 140, imageName: "mocha"),
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Нариманова 62А",
//                imageName: "machine",
//                coordinate: .init(54.341001, 48.380791),
//                menu: [
//                    DrinkModel(id: 31, name: "Кортадо", price: 110, imageName: "cortado"),
//                    DrinkModel(id: 32, name: "Гляссе", price: 170, imageName: "glace"),
//                    DrinkModel(id: 33, name: "Макиато", price: 100, imageName: "macchiato"),
//                    DrinkModel(id: 34, name: "Фраппе", price: 180, imageName: "frappe"),
//                    DrinkModel(id: 35, name: "Латте", price: 130, imageName: "latte"),
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Радищева 3",
//                imageName: "machine",
//                coordinate: .init(54.280253, 48.305803),
//                menu: [
//                    DrinkModel(id: 36, name: "Кортадо", price: 110, imageName: "cortado"),
//                    DrinkModel(id: 37, name: "Капучино", price: 120, imageName: "capp"),
//                    DrinkModel(id: 38, name: "Флэт Уайт", price: 160, imageName: "flatwhite"),
//                    DrinkModel(id: 39, name: "Гляссе", price: 170, imageName: "glace"),
//                    DrinkModel(id: 40, name: "Латте", price: 130, imageName: "latte"),
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Рябикова 13",
//                imageName: "machine",
//                coordinate: .init(54.275050, 48.306339),
//                menu: [
//                    DrinkModel(id: 41, name: "Американо", price: 90, imageName: "americano"),
//                    DrinkModel(id: 42, name: "Моккачино", price: 140, imageName: "mocha"),
//                    DrinkModel(id: 43, name: "Раф", price: 150, imageName: "raf"),
//                    DrinkModel(id: 44, name: "Кортадо", price: 110, imageName: "cortado"),
//                    DrinkModel(id: 45, name: "Айриш", price: 200, imageName: "irish")
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Ленина 5",
//                imageName: "machine",
//                coordinate: .init(54.321487, 48.386235),
//                menu: [
//                    DrinkModel(id: 46, name: "Американо", price: 90, imageName: "americano"),
//                    DrinkModel(id: 47, name: "Капучино", price: 120, imageName: "capp"),
//                    DrinkModel(id: 48, name: "Латте", price: 130, imageName: "latte"),
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Ягодинская 4",
//                imageName: "machine",
//                coordinate: .init(54.320337, 48.256253),
//                menu: [
//                    DrinkModel(id: 49, name: "Моккачино", price: 140, imageName: "mocha"),
//                    DrinkModel(id: 50, name: "Раф", price: 150, imageName: "raf"),
//                    DrinkModel(id: 51, name: "Латте", price: 130, imageName: "latte"),
//                    
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Рахова 22",
//                imageName: "machine",
//                coordinate: .init(54.296411, 48.257449),
//                menu: [
//                    DrinkModel(id: 52, name: "Эспрессо", price: 80, imageName: "espresso"),
//                    DrinkModel(id: 53, name: "Американо", price: 90, imageName: "americano"),
//                    DrinkModel(id: 54, name: "Моккачино", price: 140, imageName: "mocha"),
//                    DrinkModel(id: 55, name: "Раф", price: 150, imageName: "raf"),
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "пр. Гая 124",
//                imageName: "machine",
//                coordinate: .init(54.274248, 48.337316),
//                menu: [
//                    DrinkModel(id: 56, name: "Моккачино", price: 140, imageName: "mocha"),
//                    DrinkModel(id: 57, name: "Раф", price: 150, imageName: "raf"),
//                    DrinkModel(id: 58, name: "Кортадо", price: 110, imageName: "cortado"),
//                    DrinkModel(id: 59, name: "Айриш", price: 200, imageName: "irish")
//                ]
//            ),
//            MachineModel(
//                id: 6,
//                title: "Автозаводская 35",
//                imageName: "machine",
//                coordinate: .init(54.252919, 48.299709),
//                menu: [
//                    DrinkModel(id: 60, name: "Американо", price: 90, imageName: "americano"),
//                    DrinkModel(id: 61, name: "Капучино", price: 120, imageName: "capp"),
//                    DrinkModel(id: 62, name: "Моккачино", price: 140, imageName: "mocha"),
//                    DrinkModel(id: 63, name: "Раф", price: 150, imageName: "raf")
//                ]
//            )
//        ]
//    }
//
//    func machine(id: Int) -> MachineModel? {
//        list.first(where: { $0.id == id })
//    }
//}
