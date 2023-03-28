//
//  ContentView.swift
//  Algo-Rhythm Watch Watch App
//
//  Created by Ruth Negate on 2/28/23.
//

import SwiftUI

import SwiftUI
import HealthKit

struct ContentView: View {
    private var healthStore = HKHealthStore()
    
    @State private var bpm = 0
    
    var body: some View {
        VStack{
            Text("Algo-Rhythm").font(.system(size: 25))
            Text("WatchKit").font(.system(size: 25))
            Spacer()
            Text("\(bpm)" + "BPM").fontWeight(.regular).font(.system(size: 40)).foregroundColor(.red)
        }
        .padding()
        .onAppear(perform: getHeartbeat)
    }

    func getHeartbeat() {
        let read = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!])
        let share = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!])
        healthStore.requestAuthorization(toShare: share, read: read) {(chk, error) in
            if(chk) {
                print("perms granted")
                getHeartRateQuery()
            }
        }
    }
    
    private func getHeartRateQuery() {
        let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            query, samples, deletedObjects, queryAnchor, error in
            
        guard let samples = samples as? [HKQuantitySample] else {
            return
        }
            
        for sample in samples {
            self.bpm = Int(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
            
        }
            
        WatchConnectivityManager.shared.send(String(Int(self.bpm)))

        }

        let query = HKAnchoredObjectQuery(type: HKObjectType.quantityType(forIdentifier: .heartRate)!, predicate: HKQuery.predicateForObjects(from: [HKDevice.local()]), anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: updateHandler)
        
        query.updateHandler = updateHandler
        
        healthStore.execute(query)
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
