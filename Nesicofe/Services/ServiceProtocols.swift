//
//  ServiceProtocols.swift
//  Nesicofe
//
//  Created by dev on 29/08/2025.
//
import CoreLocation
import UIKit
import Combine

protocol AddressProviding: AnyObject {
    var currentAddress: String { get }
    var currentCenter: CLLocationCoordinate2D { get }
}
