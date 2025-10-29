//
//  UIViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

extension UIViewController {
    func alert(_ title: String, _ message: String, ok: String = "OK") {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: ok, style: .default))
        present(a, animated: true)
    }

    func confirm(_ title: String, _ message: String, ok: String = "OK", cancel: String = "Отмена", onOK: @escaping () -> Void) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: cancel, style: .cancel))
        a.addAction(UIAlertAction(title: ok, style: .default, handler: { _ in onOK() }))
        present(a, animated: true)
    }

    func showTextPrompt(title: String, message: String?, placeholder: String?, initial: String?, onText: @escaping (String) -> Void) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addTextField { tf in
            tf.placeholder = placeholder
            tf.text = initial
            tf.returnKeyType = .done
        }
        a.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        a.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            let text = a.textFields?.first?.text ?? ""
            onText(text)
        }))
        present(a, animated: true)
    }
}
