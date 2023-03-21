//
//  ContentView.swift
//  videoplayer
//
//  Created by 김효찬 on 2023/03/20.
//

import SwiftUI
import AVKit

struct Event: Identifiable, Codable {
    let id: Int
    let name: String
    let url: String
}

struct ContentView: View {
    @State var events: [Event] = []
    @State var showAlert = false
    @State var selectedEvent: Event?
    @State var isPlayingVideo = false
    
    var body: some View {
        NavigationView {
            List(events) { event in
                            NavigationLink(destination: VideoPlayerView(url: URL(string: event.url)!)) {
                                Text(event.name)
                            }
                        }
            .navigationBarTitle("라이브 경기")
            .navigationBarItems(
                trailing: Button(
                    action: {
                        self.fetchData()
                    }
                ) {
                    Image(systemName: "arrow.clockwise")
                }
            )
            .onAppear {
                self.fetchData()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Network Error"), message: Text("Failed to fetch data"), dismissButton: .default(Text("OK")){
                        self.showAlert = false
                    }
                )
            }
        }
    }
    
    func fetchData() {
        //clear lists
        self.events = []
        guard let url = URL(string: "https://www.spotvnow.co.kr/api/v2/home/web") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print(error.localizedDescription)
                self.showAlert = true
                return
            }
            
            guard let data = data else {
                self.showAlert = true
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                //print("json: \(json)")
                guard let tupleArray = json as? [Any] else {
                    print("Failed to parse JSON data")
                    self.showAlert = true
                    return
                }
                for (index, element) in tupleArray.enumerated() {
                    guard let dictionary = element as? [String: Any] else {
                        print("Failed to parse dictionary at index \(index)")
                        continue
                    }
                    //print("dictionary \(index + 1): \(dictionary)")
                    if dictionary["mainCategoryId"] as! Int != 22{
                        //print("not 22")
                        continue
                    }
                    print("dictionary \(index + 1): \(dictionary)")
                    guard let dataArray = dictionary["data"] as? [String: Any],
                          let listArray = dataArray["list"] as? [[String: Any]] else {
                        print("Failed to parse JSON data")
                        return
                    }
                    print("listArray: \(listArray)")
                var events: [Event] = []
                for item in listArray {
                    guard let id = item["id"] as? Int, let title = item["title"] as? String else { continue }
                    
                    guard let liveURLString = "https://www.spotvnow.co.kr/api/v2/live/\(id)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                          let liveURL = URL(string: liveURLString) else { continue }
                    
                    URLSession.shared.dataTask(with: liveURL) { data, response, error in
                        if let error = error {
                            print(error.localizedDescription)
                            self.showAlert = true
                            return
                        }
                        
                        guard let data = data else {
                            self.showAlert = true
                            return
                        }
                        
                        do {
                            let json = try JSONSerialization.jsonObject(with: data, options: [])
                            guard let dictionary = json as? [String: Any], let hlsUrl = dictionary["hlsUrl"] as? String else { return }
                            let event = Event(id: id, name: title, url: hlsUrl)
                            events.append(event)
                            DispatchQueue.main.async {
                                self.events = events
                            }
                        } catch {
                            print(error.localizedDescription)
                        }
                    }.resume()
                }
            }
            } catch {
                print(error.localizedDescription)
            }
        }.resume()
    }
    struct VideoPlayerView: View {
            let url: URL
            
            @State private var player: AVPlayer?
            
            var body: some View {
                Group {
                    if let player = player {
                        VideoPlayer(player: player)
                            .onDisappear {
                                // Stop the video and deallocate the player when the view disappears
                                player.pause()
                                self.player = nil
                            }
                    } else {
                        Text("Loading...")
                            .onAppear {
                                // Create the player and start loading the video when the view appears
                                self.player = AVPlayer(url: url)
                                self.player?.play()
                            }
                    }
                }
            }
        }

}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
