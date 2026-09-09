//
//  ApiService.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation



class ApiService {
    static let shared = ApiService()
    
    let url: String = "https://brapi.dev/api/v2"
    let limtit: Int = 50
    
    func getAllTickers(for page: Int, isFirstPage: Bool, completion: @escaping (Result<StockListResponse, CotlaError>) -> Void) {
        
        print(page)
        
        let url = URL(string: "\(self.url)/tickers?page=\(page)&limit=\(self.limtit)")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                completion(.failure(.invalidURL))
                return
            }
            
           URLSession.shared.dataTask(with: url) { data, response, error in
                if let _ = error {
                   return completion(.failure(.invalidData))
                }
                
                guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                   return completion(.failure(.invalidResponse))
                }
            }
            
            do {
                let decoder                             = JSONDecoder()
                let stocks: StockListResponse           = try decoder.decode(StockListResponse.self, from: data)
                return completion(.success(stocks))
            }
            catch {
                completion(.failure(.decodingFailed))
            }
        }
        .resume()
    }
}
