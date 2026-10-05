//
//  EvrryEmailService.swift
//  EvrryConsumer
//
//  Elifsi Technologies Private Limited
//  Dispatches emails via Supabase Edge Function (`send-email`).
//  Zero secret keys embedded in iOS binary.
//

import Foundation
import Supabase

public struct InvoiceLineItemPayload: Codable {
    public let name: String
    public let quantity: Int
    public let unitPricePaisa: Int64
    public let packagingUnit: String?
    public let itemNote: String?
    
    public init(name: String, quantity: Int, unitPricePaisa: Int64, packagingUnit: String? = nil, itemNote: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.unitPricePaisa = unitPricePaisa
        self.packagingUnit = packagingUnit
        self.itemNote = itemNote
    }
}

public struct InvoiceDataPayload: Codable {
    public let orderNo: String
    public let placedAt: String
    public let customerName: String
    public let customerEmail: String
    public let customerPhone: String?
    public let deliveryAddress: String?
    public let merchantName: String
    public let merchantAddress: String?
    public let merchantPan: String?
    public let paymentMethod: String
    public let items: [InvoiceLineItemPayload]
    public let subtotalPaisa: Int64
    public let deliveryFeePaisa: Int64
    public let platformFeePaisa: Int64
    public let taxPaisa: Int64
    public let discountPaisa: Int64?
    public let totalPaisa: Int64
    
    public init(
        orderNo: String,
        placedAt: String,
        customerName: String,
        customerEmail: String,
        customerPhone: String? = nil,
        deliveryAddress: String? = nil,
        merchantName: String,
        merchantAddress: String? = nil,
        merchantPan: String? = nil,
        paymentMethod: String,
        items: [InvoiceLineItemPayload],
        subtotalPaisa: Int64,
        deliveryFeePaisa: Int64,
        platformFeePaisa: Int64,
        taxPaisa: Int64,
        discountPaisa: Int64? = 0,
        totalPaisa: Int64
    ) {
        self.orderNo = orderNo
        self.placedAt = placedAt
        self.customerName = customerName
        self.customerEmail = customerEmail
        self.customerPhone = customerPhone
        self.deliveryAddress = deliveryAddress
        self.merchantName = merchantName
        self.merchantAddress = merchantAddress
        self.merchantPan = merchantPan
        self.paymentMethod = paymentMethod
        self.items = items
        self.subtotalPaisa = subtotalPaisa
        self.deliveryFeePaisa = deliveryFeePaisa
        self.platformFeePaisa = platformFeePaisa
        self.taxPaisa = taxPaisa
        self.discountPaisa = discountPaisa
        self.totalPaisa = totalPaisa
    }
}

public struct OtpDataPayload: Codable {
    public let recipientName: String?
    public let otpCode: String
    public let validMinutes: Int
    public let purpose: String?
    
    public init(recipientName: String? = nil, otpCode: String, validMinutes: Int = 10, purpose: String? = nil) {
        self.recipientName = recipientName
        self.otpCode = otpCode
        self.validMinutes = validMinutes
        self.purpose = purpose
    }
}

private struct SendInvoiceEnvelope: Codable {
    let action: String = "order_invoice"
    let to: String
    let invoiceData: InvoiceDataPayload
}

private struct SendOtpEnvelope: Codable {
    let action: String = "verification_otp"
    let to: String
    let otpData: OtpDataPayload
}

public struct SendEmailResponse: Codable {
    public let success: Bool
    public let id: String?
    public let error: String?
    public let mock: Bool?
}

public final class EvrryEmailService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Requests server-side email dispatch for customer order invoice
    public func sendOrderInvoice(to email: String, invoiceData: InvoiceDataPayload) async throws -> SendEmailResponse {
        let envelope = SendInvoiceEnvelope(to: email, invoiceData: invoiceData)
        return try await client.functions.invoke(
            "send-email",
            options: FunctionInvokeOptions(body: envelope)
        )
    }
    
    /// Requests server-side email dispatch for 6-digit OTP verification
    public func sendVerificationOtp(to email: String, otpCode: String, recipientName: String? = nil) async throws -> SendEmailResponse {
        let envelope = SendOtpEnvelope(
            to: email,
            otpData: OtpDataPayload(recipientName: recipientName, otpCode: otpCode)
        )
        return try await client.functions.invoke(
            "send-email",
            options: FunctionInvokeOptions(body: envelope)
        )
    }
}
