// NoteStore.swift

import Foundation
import UIKit    // for UIDevice
import Combine  // for ObservableObject & @Published
import NaturalLanguage
import Tokenizers
import CoreML
import Embeddings
import KDTree
import SwiftFaiss

let factoids: [String] = [
    "A group of flamingos is called a 'flamboyance.'",
    "Octopuses have three hearts.",
    "A snail can sleep for up to three years.",
    "Elephants can recognize themselves in a mirror.",
    "Cows have best friends and get stressed when separated.",
    "Koalas have fingerprints that are almost identical to humans'.",
    "Sea otters hold hands while sleeping to avoid drifting apart.",
    "A group of crows is called a 'murder.'",
    "Sloths can take up to a month to digest a single leaf.",
    "The heart of a blue whale is as large as a small car.",
    "Camels have three sets of eyelids to protect against sand.",
    "Some turtles can breathe through their butts.",
    "Honey never spoils—pots from ancient Egypt are still edible.",
    "Dolphins call each other by name using unique whistles.",
    "Hummingbirds can fly backwards.",
    "The Eiffel Tower can grow over 6 inches taller in summer heat.",
    "Tokyo is the world’s most populous city.",
    "Venice is sinking at a rate of about 1–2 millimeters per year.",
    "New York City has over 800 languages spoken.",
    "London has a city within it called 'The City of London.'",
    "Sydney Opera House’s design was inspired by orange segments.",
    "Reykjavik, Iceland, is powered almost entirely by renewable energy.",
    "In Rome, there are more fountains than any other city in the world.",
    "The Great Fire of London happened in 1666 and lasted three days.",
    "Napoleon was once attacked by a swarm of bunnies.",
    "The shortest war in history lasted only 38 minutes (Anglo-Zanzibar War).",
    "Julius Caesar was once kidnapped by pirates.",
    "Cleopatra lived closer in time to the moon landing than to the pyramids.",
    "Vikings used bones to make skis.",
    "Genghis Khan founded the largest contiguous empire in history.",
    "The Berlin Wall stood for 28 years.",
    "The Titanic was discovered in 1985, 73 years after it sank.",
    "Ancient Romans used urine as laundry detergent.",
    "Leonardo da Vinci could write with one hand and draw with the other.",
    "The oldest known 'your mom' joke is over 3,500 years old.",
    "Water can boil and freeze at the same time (triple point).",
    "Bananas are naturally radioactive due to potassium.",
    "Sharks existed before trees evolved.",
    "The human body glows in the dark—just not enough to see.",
    "Hot water can freeze faster than cold water (Mpemba effect).",
    "A teaspoon of neutron star material weighs about a billion tons.",
    "The sun makes up 99.86% of the solar system’s mass.",
    "A day on Venus is longer than a year on Venus.",
    "The moon is slowly drifting away from Earth (about 1.5 inches per year).",
    "There are more stars in the universe than grains of sand on Earth.",
    "The Milky Way is on a collision course with the Andromeda Galaxy.",
    "You can’t burp in space because there’s no gravity to separate gas and liquid.",
    "The footprints on the moon could last millions of years.",
    "A comet's tail always points away from the sun.",
    "Space smells like seared steak and welding fumes.",
    "Lightning strikes the Earth around 100 times per second.",
    "Mount Everest grows about 4 millimeters taller each year.",
    "Bamboo can grow up to 35 inches in a single day.",
    "Some deserts are cold—Antarctica is the largest desert on Earth.",
    "The Amazon rainforest produces about 20% of the world's oxygen.",
    "A single bolt of lightning is five times hotter than the surface of the sun.",
    "The Sahara was once a lush, green region with lakes and vegetation.",
    "The deepest part of the ocean is deeper than Mount Everest is tall.",
    "The Mariana Trench is over 36,000 feet deep.",
    "Whales can hold their breath for over an hour.",
    "Jellyfish have survived five mass extinctions.",
    "Birds are the closest living relatives to dinosaurs.",
    "The platypus is one of the only mammals that lays eggs.",
    "The fingerprints of a koala are indistinguishable from a human’s under a microscope.",
    "Caterpillars completely dissolve into goo inside a chrysalis before becoming butterflies.",
    "The Internet was originally called ARPANET.",
    "The first computer bug was a literal moth found in a computer.",
    "Email predates the World Wide Web.",
    "The word 'robot' comes from a Czech word meaning 'forced labor'.",
    "Google was originally called 'BackRub.'",
    "Your stomach gets a new lining every 3 to 4 days.",
    "The average adult has about 5 liters of blood.",
    "There are more bacteria in your gut than human cells in your body.",
    "Your bones are constantly being replaced—every 10 years, you have a new skeleton.",
    "The human nose can detect over 1 trillion scents.",
    "Your body has more neurons in the gut than in the spinal cord.",
    "Human thigh bones are stronger than concrete.",
    "Yawning cools your brain.",
    "People with synesthesia can 'see' sounds or 'hear' colors.",
    "The brain is sometimes more active during sleep than when awake.",
    "Your liver can regenerate even if 75% of it is removed.",
    "The tongue is made up of eight different muscles.",
    "You can't breathe and swallow at the same time.",
    "The small intestine is about 22 feet long.",
    "Hair grows faster in warm weather.",
    "Humans share about 60% of their DNA with bananas.",
    "The left lung is smaller than the right to make room for the heart.",
    "Your heartbeat syncs with the rhythm of the music you're listening to.",
    "Some people can hear the sound of their own eyeballs moving.",
    "Children have around 300 bones at birth; adults have 206.",
    "Blood is red because of iron in hemoglobin.",
    "Goosebumps are a vestigial reflex from when humans had more body hair.",
    "Sweat itself is odorless—body odor comes from bacteria breaking it down.",
    "Laughter can increase blood flow by 20%.",
    "Blinking helps keep your eyes lubricated and protected from debris.",
    "The word 'muscle' comes from Latin for 'little mouse', because muscles looked like mice under the skin.",
    "Nerve impulses travel as fast as 250 miles per hour.",
    "The average person has about 100,000 hairs on their head.",
    "Your skin is the body’s largest organ."
]

// MARK: — Networking Models

/// Payload for POST /add_note
private struct AddNoteRequest: Codable {
    let device_id: String
    let note:      String
    let folder:    String
    let notebook:  String
}

/// Response from POST /add_note
private struct AddNoteResponse: Codable {
    let id: String
}

/// Payload for POST /get_response
private struct GetResponseRequest: Codable {
    let device_id: String
    let question:  String
    let k:         String
}

/// Model for GET /get_response
struct AIResponse: Codable, Identifiable {
    let id:       String
    let answer:   String
    let folder:   String
    let notebook: String
    var onDeviceAnswer: String?
}

/// Payload for POST /submit_feedback
private struct SubmitFeedbackRequest: Codable {
    let username: String
    let question: String
    let answer:   String
    let is_pair:  Bool
}

/// Model returned by GET /get_user_notes
private struct ServerNote: Codable {
    let folder:   String
    let id:       String
    let note:     String
    let notebook: String
}

/// Payload for PUT /update_note
private struct UpdateNotePayload: Codable {
    let device_id: String
    let note_id:   String
    let note:      String
    enum CodingKeys: String, CodingKey {
        case device_id, note_id, note
    }
}

// MARK: — Local Models

struct NoteBook: Identifiable, Hashable, Comparable {
    let id:    UUID
    let title: String
    var notes: [Note]
    static func < (lhs: NoteBook, rhs: NoteBook) -> Bool { lhs.title < rhs.title }
}

struct Note: Identifiable, Hashable {
    let id:   String
    var text: String
}

// MARK: — The Store

struct NoteVectorPair: KDTreePoint {
    let embedding: [Double]
    let note: String
    // would be nice not to hard code this
    public static var dimensions: Int {
        return 512
    }
    
    public func kdDimension(_ dimension: Int) -> Double {
        return embedding[dimension]
    }
    
    public func squaredDistance(to otherPoint: NoteVectorPair) -> Double {
        var d = 0.0
        for i in 0..<embedding.count {
            d += (embedding[i] - otherPoint.embedding[i]) * (embedding[i] - otherPoint.embedding[i])
        }
        return d
    }
}

final class NoteStore: ObservableObject {
    @Published var notesByFolder: [String: [String: NoteBook]] = [
        "Notes":    [:],
        "Work":     [:],
        "Personal": [:]
    ]
    let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    var tokenizer: Tokenizer?
    var model: all_mpnet_base_v2?
    var noteEmbeddings: [String: [Double]] = [:]
    var noteTree = KDTree<NoteVectorPair>(values: [])
    var noteFAISS: FlatIndex?
    var noteFAISSMap: [String]?
    var modelBundle: Roberta.ModelBundle?
    var prepopulated = true
    // MARK: — Highlighting
    /// ID of the note to highlight when opening a detail view
    @Published var highlightedNoteID: String? = nil

    private var userID: String {
        UIDevice.current.identifierForVendor!.uuidString
    }

    private var baseURL: URL {
        let defaultURL = "https://happily-complete-stinkbug.ngrok-free.app/"
        let urlString = UserDefaults.standard.string(forKey: "apiURL") ?? defaultURL
        guard let url = URL(string: urlString) else {
            fatalError("Invalid `apiURL` in UserDefaults: \(urlString)")
        }
        return url
    }
    
    func prefetch() async {
//        tokenizer = try? await AutoTokenizer.from(pretrained: "mixedbread-ai/mxbai-embed-large-v1")
//        model = try? all_mpnet_base_v2()

        do {
            modelBundle = try await Roberta.loadModelBundle(
                from: "sentence-transformers/all-distilroberta-v1"
            )
        } catch {
            print("\(error.localizedDescription)")
        }
        
        print("model \(model)")
    }
    
    func unsqueeze(_ array: MLMultiArray, axis: Int) throws -> MLMultiArray {
        var newShape = array.shape.map { $0.intValue }
        newShape.insert(1, at: axis)
        let result = try MLMultiArray(shape: newShape.map(NSNumber.init), dataType: array.dataType)
        for i in 0..<array.count {
            result[i] = array[i]
        }
        return result
    }
    
    private var hasFetchedNotes = false
    
    func testTokenizer() async throws {
        let start = Date()
        guard let tokenizer = tokenizer, let model = model else {
            return
        }
        let encoded = tokenizer.encode(text: "hello test this is a sample sentence that we might encode using our model.  How long would it take to do so?")
        
        if let multiArrayEnc = try? MLMultiArray(encoded), let attentionMask = try? MLMultiArray(Array(repeating: 1, count: encoded.count)), let multiArrayUnsqueezed = try? unsqueeze(multiArrayEnc, axis: 0), let attentionMaskUnsqueezed = try? unsqueeze(attentionMask, axis: 0) {
            // Prepare input (depends on your model)
            let input = all_mpnet_base_v2Input(input_ids: multiArrayUnsqueezed, attention_mask: attentionMaskUnsqueezed)
            // Make a prediction
            guard let output = try? await model.prediction(input: input) else {
                fatalError("Failed to make prediction")
            }
            print("time \(Date().timeIntervalSince(start))")
            let count = output.hidden_states.count
            var values: [Double] = []
            for i in 0..<count {
                values.append(output.hidden_states[i].doubleValue)
            }
            print(values)
            print("prediction \(output.hidden_states.debugDescription)")
        }

    }
    
    /// Fetches all user notes once per app launch.
    func fetchUserNotes() {
        if !prepopulated {
            prepopulated = true
            Task {
                for f in factoids {
                    addNote(f, title: "Factoids", folder: "Default")
                }
            }
        }
//        Task {
//            await prefetch()
//            for _ in 0..<10000 {
//                let startTime = Date()
//                let text = "hello test this is a sample sentence that we might encode using our model.  How long would it take to do so?"
//                // encode text
////                if let encoded = try modelBundle?.encode(text) {
////                    let result = await encoded.cast(to: Float.self).shapedArray(of: Float.self).scalars
////                    print("success \(Date().timeIntervalSince(startTime))")
////                }
//                let texts = Array(repeating: text, count: 100)
//                if let encoded = try? modelBundle?.batchEncode(texts) {
//                    print("success \(Date().timeIntervalSince(startTime))")
//                }
//
//            }
//        }
        
        guard !hasFetchedNotes else { return }
        hasFetchedNotes = true

        let endpoint = baseURL.appendingPathComponent("get_user_notes")
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "device_id", value: userID)]
        guard let url = comps?.url else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("fetchUserNotes error:", error)
                return
            }
            guard let data = data else { return }
            do {
                let serverNotes = try JSONDecoder().decode([ServerNote].self, from: data)
                let filtered = serverNotes.filter { $0.note != $0.notebook }
                DispatchQueue.main.async {
                    var updated = self.notesByFolder
                    for s in filtered {
                        let folderKey = s.folder.lowercased() == "default" ? "Notes" : s.folder.capitalized
                        var folderMap = updated[folderKey] ?? [:]
                        if var book = folderMap[s.notebook] {
                            book.notes.append(Note(id: s.id, text: s.note))
                            folderMap[s.notebook] = book
                        } else {
                            folderMap[s.notebook] = NoteBook(
                                id: UUID(),
                                title: s.notebook,
                                notes: [Note(id: s.id, text: s.note)]
                            )
                        }
                        if let v = self.embedding?.vector(for: s.note) {
                            self.noteEmbeddings[s.note] = v
                        }
                        updated[folderKey] = folderMap
                    }
                    self.notesByFolder = updated
                    self.noteTree = KDTree<NoteVectorPair>(values: Array(self.noteEmbeddings.map({(k, v) in NoteVectorPair(embedding: v, note: k)})))
                    // TODO: avoid hardcode
                    self.noteFAISS = try? FlatIndex(d: 512, metricType: .innerProduct)
                    var normalizedEmbeddings = [[Float]]()
                    self.noteFAISSMap = []
                    for (note, embedding) in self.noteEmbeddings {
                        var normalizedEmbedding: [Float] = []
                        var ssq = 0.0
                        for v in embedding {
                            ssq += v * v
                        }
                        let norm = sqrt(ssq)
                        for v in embedding {
                            normalizedEmbedding.append(Float(v/norm))
                        }
                        normalizedEmbeddings.append(normalizedEmbedding)
                        self.noteFAISSMap?.append(note)
                    }
                    
                    try? self.noteFAISS?.add(normalizedEmbeddings)
                    //let result = try index.search(normalizedQueries, k: 10)

                    print("noteTree count \(self.noteTree.count)")
                }
            } catch {
                print("fetchUserNotes decode error:", error)
            }
        }
        .resume()
    }

    /// Creates a new, empty notebook under the given folder.
    func addNoteBook(title: String, to folder: String) {
        DispatchQueue.main.async {
            var fm = self.notesByFolder[folder] ?? [:]
            guard fm[title] == nil else { return }
            fm[title] = NoteBook(id: UUID(), title: title, notes: [])
            self.notesByFolder[folder] = fm
        }
    }

    /// Sends a new note to POST /add_note, decodes the server’s new `id`, then updates UI.
    func addNote(_ text: String, title: String, folder: String) {
        if let v = embedding?.vector(for: text) {
            noteEmbeddings[text] = v
        }
        let endpoint = baseURL.appendingPathComponent("add_note")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddNoteRequest(device_id: userID, note: text, folder: folder, notebook: title)
        guard let body = try? JSONEncoder().encode(payload) else {
            print("addNote encoding error")
            return
        }
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { data, resp, error in
            if let error = error {
                print("addNote network error:", error)
                return
            }
            guard let data = data,
                  let http = resp as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                print("addNote bad response")
                return
            }
            do {
                let created = try JSONDecoder().decode(AddNoteResponse.self, from: data)
                DispatchQueue.main.async {
                    let folderKey = folder.lowercased() == "default" ? "Notes" : folder.capitalized
                    var all = self.notesByFolder
                    var folderMap = all[folderKey] ?? [:]
                    if var book = folderMap[title] {
                        book.notes.append(Note(id: created.id, text: text))
                        folderMap[title] = book
                    } else {
                        folderMap[title] = NoteBook(
                            id: UUID(), title: title,
                            notes: [Note(id: created.id, text: text)]
                        )
                    }
                    all[folderKey] = folderMap
                    self.notesByFolder = all
                }
            } catch {
                print("addNote decode error:", error)
            }
        }
        .resume()
    }

    /// Sends only the required fields to update a note on the server, then patches the local store on success.
    func syncSingleMessage(id: String, text: String, folder: String, notebook: String) {
        let endpoint = baseURL.appendingPathComponent("update_note")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = UpdateNotePayload(device_id: userID, note_id: id, note: text)
        guard let body = try? JSONEncoder().encode(payload) else {
            print("syncSingleMessage encoding error")
            return
        }
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { data, resp, error in
            if let error = error {
                print("syncSingleMessage network error:", error)
                return
            }
            guard let http = resp as? HTTPURLResponse else {
                print("syncSingleMessage: no HTTPURLResponse")
                return
            }
            if !(200..<300 ~= http.statusCode) {
                let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "—empty—"
                print("syncSingleMessage bad response: \(http.statusCode) — \(bodyStr)")
                return
            }
            DispatchQueue.main.async {
                var all = self.notesByFolder
                var fm = all[folder] ?? [:]
                if var book = fm[notebook], let idx = book.notes.firstIndex(where: { $0.id == id }) {
                    book.notes[idx].text = text
                    fm[notebook] = book
                    all[folder] = fm
                    self.notesByFolder = all
                }
            }
        }
        .resume()
    }

    /// Deletes a single note via DELETE /delete_note/{device_id}/{note_id}, then removes it locally.
    func deleteNote(id: String, notebook: String, folder: String) {
        let endpoint = baseURL
            .appendingPathComponent("delete_note")
            .appendingPathComponent(userID)
            .appendingPathComponent(id)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: req) { _, resp, error in
            if let error = error {
                print("deleteNote network error:", error)
                return
            }
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                print("deleteNote bad response")
                return
            }
            DispatchQueue.main.async {
                var all = self.notesByFolder
                var fm = all[folder] ?? [:]
                if var book = fm[notebook] {
                    book.notes.removeAll { $0.id == id }
                    fm[notebook] = book
                    all[folder] = fm
                    self.notesByFolder = all
                }
            }
        }
        .resume()
    }

    /// Deletes all notes via DELETE /delete_user_notes/{device_id}, then clears locally.
    func deleteAllNotes() {
        let endpoint = baseURL
            .appendingPathComponent("delete_user_notes")
            .appendingPathComponent(userID)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: req) { _, resp, error in
            if let error = error {
                print("deleteAllNotes network error:", error)
                return
            }
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                print("deleteAllNotes bad response")
                return
            }
            DispatchQueue.main.async {
                self.notesByFolder = ["Notes": [:], "Work": [:], "Personal": [:]]
                self.hasFetchedNotes = false
            }
        }
        .resume()
    }

    /// Deletes an entire notebook: fires DELETE for each note in it, then removes the notebook.
    func deleteNoteBook(title: String, in folder: String) {
        guard let folderMap = notesByFolder[folder], let book = folderMap[title] else { return }
        let ids = book.notes.map { $0.id }
        ids.forEach { noteID in
            let endpoint = baseURL
                .appendingPathComponent("delete_note")
                .appendingPathComponent(userID)
                .appendingPathComponent(noteID)
            var req = URLRequest(url: endpoint)
            req.httpMethod = "DELETE"
            URLSession.shared.dataTask(with: req).resume()
        }
        DispatchQueue.main.async {
            var all = self.notesByFolder
            var fm = all[folder] ?? [:]
            fm.removeValue(forKey: title)
            all[folder] = fm
            self.notesByFolder = all
        }
    }

    // MARK: — AI / Feedback
    
    func getTopNoteOnDevice(question: String)->String? {
        let timeStart = Date()
        guard let v = embedding?.vector(for: question) else {
            return nil
        }
        var similiarities: [Double] = []
        var notes: [String] = []
        for (note, vv) in noteEmbeddings {
            var sim = 0.0
            var vSsq = 0.0
            var vvSsq = 0.0
            for i in 0..<v.count {
                sim += v[i]*vv[i]
                vSsq += v[i]*v[i]
                vvSsq += vv[i]*vv[i]
            }
            notes.append(note)
            similiarities.append(sim / sqrt(vSsq) / sqrt(vvSsq))
        }
        print("time \(Date().timeIntervalSince(timeStart))")
        let startKDTree = Date()
        let closest = noteTree.nearest(to: NoteVectorPair(embedding: v, note: question))
        print("closest note kdtree \(closest?.note ?? "none found")")
        print("time \(Date().timeIntervalSince(startKDTree))")
        
        let faisstimeStart = Date()
        if let result = try? noteFAISS?.search([v.map({Float($0)})], k: 10) {
            print("Time FAISS \(Date().timeIntervalSince(faisstimeStart))")
            print(noteFAISSMap?[result.labels[0][0]])
        }

        
        if let (index, _) = similiarities.enumerated().max(by: { $0.element < $1.element }) {
            return notes[index]
        }

        return nil
    }

    func fetchTopNotes(question: String, k: Int) async throws -> [AIResponse] {
        let onDevice = getTopNoteOnDevice(question: question)
        print("top \(onDevice ?? "none")")
        let endpoint = baseURL.appendingPathComponent("get_response")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = GetResponseRequest(device_id: userID, question: question, k: String(k))
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        var respDecoded = try JSONDecoder().decode([AIResponse].self, from: data)
        if respDecoded.count > 0 {
            respDecoded[0].onDeviceAnswer = onDevice
        }
        return respDecoded
    }

    func submitFeedback(question: String, answer: String, isPair: Bool) {
        let endpoint = baseURL.appendingPathComponent("submit_feedback")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = SubmitFeedbackRequest(username: userID, question: question, answer: answer, is_pair: isPair)
        request.httpBody = try? JSONEncoder().encode(payload)
        URLSession.shared.dataTask(with: request).resume()
    }
}
