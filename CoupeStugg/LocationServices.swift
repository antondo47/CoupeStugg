//
//  LocationServices.swift
//  Coupe stuff
//
//  Created by Do Ngoc Anh on 1/26/26.
//

import SwiftUI
import MapKit
import Combine

class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var completions: [MKLocalSearchCompletion] = []
    
    private var completer: MKLocalSearchCompleter
    private var cancellable: AnyCancellable?
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
        
        cancellable = $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.completer.queryFragment = query
            }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // updates the list of suggestions
        self.completions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // handle error simply by clearing results
        print("Error searching: \(error.localizedDescription)")
    }
    
    func search(for completion: MKLocalSearchCompletion, completionHandler: @escaping (MKMapItem?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            // IMPORTANT: Return to main thread
            DispatchQueue.main.async {
                completionHandler(response?.mapItems.first)
            }
        }
    }
}
