import Foundation

/// The library of step-through simulations. Every frame is computed by actually running
/// the algorithm, so what the learner sees is what the algorithm really does.
public enum Simulations {
    public static let ids: [String] = [
        "binaryCounter", "halving", "binarySearch", "insertionSort", "stackOps", "queueOps",
        "hashInsert", "bfs", "dfs", "bstInsert", "heapInsert", "dijkstra", "fibTable",
        "factorialStack", "gradientDescent", "gradientOvershoot", "secantTangent", "growthCurves",
    ]

    public static func make(_ id: String) -> Simulation? {
        switch id {
        case "binaryCounter": return binaryCounter()
        case "halving": return halving()
        case "binarySearch": return binarySearch()
        case "insertionSort": return insertionSort()
        case "stackOps": return stackOps()
        case "queueOps": return queueOps()
        case "hashInsert": return hashInsert()
        case "bfs": return breadthFirst()
        case "dfs": return depthFirst()
        case "bstInsert": return bstInsert()
        case "heapInsert": return heapInsert()
        case "dijkstra": return dijkstra()
        case "fibTable": return fibTable()
        case "factorialStack": return factorialStack()
        case "gradientDescent":
            return descent(
                id: id, title: "A good step size", rate: 0.35, steps: 10,
                blurb: "Gradient descent with a sensible learning rate.",
                outro: "The steps shrink on their own as the slope flattens out. It has nearly reached the minimum at x = 1."
            )
        case "gradientOvershoot":
            return descent(
                id: id, title: "Too big a step", rate: 1.8, steps: 8,
                blurb: "The same curve with a learning rate that is too large.",
                outro: "Too big a step jumps past the bottom and zig-zags, wasting effort. Any rate above 2.0 here and it would bounce further out every time and never settle."
            )
        case "secantTangent": return secantTangent()
        case "growthCurves": return growthCurves()
        default: return nil
        }
    }

    // MARK: Numbers

    static func binaryCounter() -> Simulation {
        let places = [8, 4, 2, 1]
        var frames: [SimFrame] = []
        var previous = [false, false, false, false]
        for n in 0...15 {
            let bits = places.map { n & $0 != 0 }
            var cells: [SimCell] = []
            var flips = 0
            for i in 0..<4 {
                let flipped = n > 0 && bits[i] != previous[i]
                if flipped { flips += 1 }
                let mark: Mark = flipped ? .fresh : (bits[i] ? .focus : .idle)
                cells.append(SimCell(bits[i] ? "1" : "0", mark, note: String(places[i])))
            }
            let pattern = bits.map { $0 ? "1" : "0" }.joined()
            let parts = places.filter { n & $0 != 0 }.map { String($0) }
            var caption: String
            if n == 0 {
                caption = "0 is 0000: every switch is off. Each place is worth double the one to its right."
            } else if parts.count == 1 {
                caption = String(n) + " is " + pattern + ": just the " + parts[0] + "s place."
            } else {
                caption = String(n) + " is " + pattern + ": " + parts.joined(separator: " + ") + "."
            }
            if flips > 1 {
                caption += " The 1s rolled over to 0 and carried left, like an odometer."
            }
            frames.append(SimFrame(caption, .array(ArrayScene(cells: cells, label: "= " + String(n)))))
            previous = bits
        }
        return Simulation(id: "binaryCounter", title: "Counting in binary", blurb: "Four bits counting from 0 to 15.", frames: frames)
    }

    static func halving() -> Simulation {
        var cells = [SimCell("64", .focus, note: "start")]
        var frames = [SimFrame("Start with 64 items. How many times can you halve them before only 1 is left?", .array(ArrayScene(cells: cells)))]
        var value = 64
        var step = 0
        while value > 1 {
            value /= 2
            step += 1
            for i in cells.indices { cells[i].mark = .idle }
            cells.append(SimCell(String(value), .fresh, note: "step " + String(step)))
            let unit = step == 1 ? " halving so far." : " halvings so far."
            frames.append(SimFrame("Halve again: " + String(value) + ". That's " + String(step) + unit, .array(ArrayScene(cells: cells))))
        }
        cells[cells.count - 1].mark = .done
        frames.append(SimFrame("6 halvings take 64 down to 1, so log₂ 64 = 6. A billion would need only about 30.", .array(ArrayScene(cells: cells))))
        return Simulation(id: "halving", title: "Halving to one", blurb: "A logarithm counts how many halvings it takes.", frames: frames)
    }

    // MARK: Searching and sorting

    static func binarySearch() -> Simulation {
        let data = [3, 8, 12, 17, 21, 25, 31, 38, 44, 52, 60, 71]
        let target = 52
        var lo = 0
        var hi = data.count - 1
        var checks = 0

        func scene(mid: Int?, found: Bool = false) -> SimScene {
            var cells: [SimCell] = []
            for (i, value) in data.enumerated() {
                var mark: Mark = (i < lo || i > hi) ? .muted : .idle
                if i == mid { mark = found ? .done : .focus }
                cells.append(SimCell(String(value), mark, note: String(i)))
            }
            var markers: [SimMarker] = []
            if lo <= hi {
                markers.append(SimMarker(lo, "low"))
                markers.append(SimMarker(hi, "high"))
            }
            if let mid { markers.append(SimMarker(mid, "mid")) }
            return .array(ArrayScene(cells: cells, markers: markers, label: "Looking for 52"))
        }

        var frames = [SimFrame("Find 52 in this sorted list of 12 numbers. Start by checking the middle.", scene(mid: nil))]
        while lo <= hi {
            let mid = (lo + hi) / 2
            checks += 1
            let value = data[mid]
            if value == target {
                let caption = "Found 52 after " + String(checks) + " checks. Checking one by one from the left would have taken " + String(mid + 1) + "."
                frames.append(SimFrame(caption, scene(mid: mid, found: true)))
                break
            }
            frames.append(SimFrame("Check the middle: " + String(value) + ".", scene(mid: mid)))
            if value < target {
                lo = mid + 1
                frames.append(SimFrame(String(value) + " is less than 52, so 52 can only be to the right. Discard the left half.", scene(mid: nil)))
            } else {
                hi = mid - 1
                frames.append(SimFrame(String(value) + " is more than 52, so 52 can only be to the left. Discard the right half.", scene(mid: nil)))
            }
        }
        return Simulation(id: "binarySearch", title: "Binary search", blurb: "Halving the search range with every check.", frames: frames)
    }

    static func insertionSort() -> Simulation {
        var a = [5, 2, 8, 1, 9, 3]

        func scene(sorted: Int, focus: Int? = nil, compare: Int? = nil) -> SimScene {
            var cells: [SimCell] = []
            for (i, value) in a.enumerated() {
                var mark: Mark = i <= sorted ? .done : .idle
                if i == compare { mark = .compare }
                if i == focus { mark = .focus }
                cells.append(SimCell(String(value), mark))
            }
            return .array(ArrayScene(cells: cells))
        }

        var frames = [SimFrame("Insertion sort: take each item in turn and slide it left until the item before it is smaller. One item on its own is already sorted.", scene(sorted: 0))]
        for i in 1..<a.count {
            var j = i
            frames.append(SimFrame("Take " + String(a[j]) + ".", scene(sorted: i - 1, focus: j)))
            while j > 0 && a[j - 1] > a[j] {
                frames.append(SimFrame(String(a[j - 1]) + " is bigger than " + String(a[j]) + ", so swap them.", scene(sorted: i, focus: j, compare: j - 1)))
                a.swapAt(j - 1, j)
                j -= 1
            }
            if j > 0 {
                frames.append(SimFrame(String(a[j - 1]) + " is smaller, so " + String(a[j]) + " stops here.", scene(sorted: i, focus: j, compare: j - 1)))
            } else {
                frames.append(SimFrame(String(a[j]) + " is the smallest so far, so it goes to the front.", scene(sorted: i, focus: j)))
            }
        }
        frames.append(SimFrame("Sorted. Insertion sort is quick on small or nearly sorted lists; on big ones, merge sort's halving wins.", scene(sorted: a.count - 1)))
        return Simulation(id: "insertionSort", title: "Insertion sort", blurb: "Sliding each item into place.", frames: frames)
    }

    // MARK: Stacks and queues

    private enum Op {
        case add(String)
        case remove
    }

    static func stackOps() -> Simulation {
        var stack: [String] = []
        let ops: [Op] = [.add("A"), .add("B"), .add("C"), .remove, .add("D"), .remove, .remove]

        func scene(fresh: Bool, out: String?) -> SimScene {
            var cells: [SimCell] = []
            for (i, item) in stack.enumerated() {
                let isTop = i == stack.count - 1
                cells.append(SimCell(item, isTop && fresh ? .fresh : .idle))
            }
            let markers = stack.isEmpty ? [] : [SimMarker(stack.count - 1, "top")]
            return .array(ArrayScene(cells: cells, markers: markers, vertical: true, label: out.map { "Out: " + $0 }))
        }

        var frames = [SimFrame("An empty stack. Items go on and come off at the top only.", scene(fresh: false, out: nil))]
        for op in ops {
            switch op {
            case .add(let item):
                stack.append(item)
                frames.append(SimFrame("push(" + item + "): " + item + " goes on top.", scene(fresh: true, out: nil)))
            case .remove:
                let item = stack.removeLast()
                frames.append(SimFrame("pop() takes the top item: " + item + ". Last in, first out.", scene(fresh: false, out: item)))
            }
        }
        return Simulation(id: "stackOps", title: "Push and pop", blurb: "A stack only touches its top.", frames: frames)
    }

    static func queueOps() -> Simulation {
        var queue: [String] = []
        let ops: [Op] = [.add("A"), .add("B"), .add("C"), .remove, .add("D"), .remove, .remove]

        func scene(fresh: Bool, out: String?) -> SimScene {
            var cells: [SimCell] = []
            for (i, item) in queue.enumerated() {
                let isBack = i == queue.count - 1
                cells.append(SimCell(item, isBack && fresh ? .fresh : .idle))
            }
            var markers: [SimMarker] = []
            if !queue.isEmpty {
                markers.append(SimMarker(0, "front"))
                markers.append(SimMarker(queue.count - 1, "back"))
            }
            return .array(ArrayScene(cells: cells, markers: markers, label: out.map { "Out: " + $0 }))
        }

        var frames = [SimFrame("An empty queue. Items join at the back and leave from the front.", scene(fresh: false, out: nil))]
        for op in ops {
            switch op {
            case .add(let item):
                queue.append(item)
                frames.append(SimFrame("enqueue(" + item + "): " + item + " joins the back of the line.", scene(fresh: true, out: nil)))
            case .remove:
                let item = queue.removeFirst()
                frames.append(SimFrame("dequeue() serves the front: " + item + ". First in, first out.", scene(fresh: false, out: item)))
            }
        }
        return Simulation(id: "queueOps", title: "Enqueue and dequeue", blurb: "A queue serves in arrival order.", frames: frames)
    }

    // MARK: Hashing

    static func toyHash(_ key: String) -> Int {
        key.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }

    static func hashInsert() -> Simulation {
        let keys = ["cat", "dog", "owl", "bee", "ant", "fox"]
        let size = 5
        var table = [[String]](repeating: [], count: size)

        func scene(incoming: String?, target: Int?, newest: String? = nil, found: String? = nil) -> SimScene {
            let buckets = table.map { chain in
                chain.map { key -> SimCell in
                    if key == found { return SimCell(key, .done) }
                    return SimCell(key, key == newest ? .fresh : .idle)
                }
            }
            return .buckets(BucketScene(buckets: buckets, incoming: incoming, target: target))
        }

        var frames = [SimFrame("Five empty buckets. A key's bucket is computed from the key itself, so it can be found again the same way.", scene(incoming: nil, target: nil))]
        for key in keys {
            let h = toyHash(key)
            let bucket = h % size
            let codes = key.unicodeScalars.map { String($0.value) }.joined(separator: " + ")
            let math = "hash(" + key + ") = " + codes + " = " + String(h) + ", and " + String(h) + " mod 5 = " + String(bucket) + "."
            frames.append(SimFrame(math, scene(incoming: key, target: bucket)))
            let earlier = table[bucket]
            table[bucket].append(key)
            let caption: String
            if earlier.isEmpty {
                caption = key + " goes straight into bucket " + String(bucket) + "."
            } else {
                caption = "Bucket " + String(bucket) + " already holds " + earlier.joined(separator: " and ") + ": a collision. " + key + " joins the chain."
            }
            frames.append(SimFrame(caption, scene(incoming: nil, target: bucket, newest: key)))
        }
        frames.append(SimFrame("Looking up fox repeats the same sum: bucket 3, then a short walk along its chain. No scanning of the whole table.", scene(incoming: "fox", target: 3, found: "fox")))
        return Simulation(id: "hashInsert", title: "Filling a hash table", blurb: "Keys computed into buckets, with collisions chained.", frames: frames)
    }

    // MARK: Graph search

    struct DemoGraph {
        let positions: [String: Point2]
        let order: [String]
        let edges: [(String, String)]

        func neighbours(_ id: String) -> [String] {
            var result: [String] = []
            for (a, b) in edges {
                if a == id { result.append(b) }
                if b == id { result.append(a) }
            }
            return result.sorted()
        }

        static func key(_ a: String, _ b: String) -> String {
            a < b ? a + "-" + b : b + "-" + a
        }
    }

    static let searchGraph = DemoGraph(
        positions: [
            "A": Point2(0.5, 0.12), "B": Point2(0.27, 0.45), "C": Point2(0.73, 0.45),
            "D": Point2(0.12, 0.84), "E": Point2(0.4, 0.84), "F": Point2(0.62, 0.84), "G": Point2(0.88, 0.84),
        ],
        order: ["A", "B", "C", "D", "E", "F", "G"],
        edges: [("A", "B"), ("A", "C"), ("B", "D"), ("B", "E"), ("C", "F"), ("C", "G"), ("E", "F")]
    )

    static func graphScene(
        _ g: DemoGraph, done: Set<String>, waiting: Set<String>, focus: String?, used: Set<String>, footer: String
    ) -> SimScene {
        var nodes: [GraphScene.Node] = []
        for id in g.order {
            var mark: Mark = .idle
            if waiting.contains(id) { mark = .compare }
            if done.contains(id) { mark = .done }
            if id == focus { mark = .focus }
            let p = g.positions[id]!
            nodes.append(GraphScene.Node(id: id, label: id, x: p.x, y: p.y, mark: mark))
        }
        var edges: [GraphScene.Edge] = []
        for (a, b) in g.edges {
            let mark: Mark = used.contains(DemoGraph.key(a, b)) ? .done : .idle
            edges.append(GraphScene.Edge(from: a, to: b, mark: mark))
        }
        return .graph(GraphScene(nodes: nodes, edges: edges, footer: footer))
    }

    static func breadthFirst() -> Simulation {
        let g = searchGraph
        var queue = ["A"]
        var discovered: Set<String> = ["A"]
        var visited: Set<String> = []
        var used: Set<String> = []
        var order: [String] = []
        var frames = [SimFrame(
            "Breadth-first search from A. A queue holds the places waiting to be visited.",
            graphScene(g, done: visited, waiting: discovered, focus: nil, used: used, footer: "Queue: A")
        )]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            visited.insert(current)
            order.append(current)
            let fresh = g.neighbours(current).filter { !discovered.contains($0) }
            for next in fresh {
                discovered.insert(next)
                queue.append(next)
                used.insert(DemoGraph.key(current, next))
            }
            var caption = "Visit " + current + "."
            if fresh.isEmpty {
                caption += " No new neighbours to add."
            } else {
                caption += " Add its unvisited neighbours " + Atlas.list(fresh) + " to the back of the queue."
            }
            let footer = queue.isEmpty ? "Queue: empty" : "Queue: " + queue.joined(separator: " ")
            frames.append(SimFrame(caption, graphScene(g, done: visited.subtracting([current]), waiting: discovered.subtracting(visited), focus: current, used: used, footer: footer)))
        }
        frames.append(SimFrame(
            "Done. BFS visited " + order.joined(separator: ", ") + ": ring by ring, outward from A.",
            graphScene(g, done: visited, waiting: [], focus: nil, used: used, footer: "Order: " + order.joined(separator: " "))
        ))
        return Simulation(id: "bfs", title: "Breadth-first", blurb: "Explore in rings using a queue.", frames: frames)
    }

    static func depthFirst() -> Simulation {
        let g = searchGraph
        var visited: Set<String> = []
        var used: Set<String> = []
        var order: [String] = []
        var path: [String] = []
        var frames = [SimFrame(
            "Depth-first search from A: follow one path as deep as it goes, then back up and try the next branch.",
            graphScene(g, done: [], waiting: [], focus: nil, used: [], footer: "Path: (empty)")
        )]

        func snapshot(_ caption: String, focus: String) {
            let footer = "Path: " + path.joined(separator: " → ")
            frames.append(SimFrame(caption, graphScene(g, done: visited.subtracting([focus]), waiting: Set(path).subtracting([focus]), focus: focus, used: used, footer: footer)))
        }

        func visit(_ current: String) {
            visited.insert(current)
            order.append(current)
            path.append(current)
            let hasNext = g.neighbours(current).contains { !visited.contains($0) }
            snapshot("Visit " + current + "." + (hasNext ? " Go deeper." : " Dead end."), focus: current)
            for next in g.neighbours(current) where !visited.contains(next) {
                used.insert(DemoGraph.key(current, next))
                visit(next)
                let more = g.neighbours(current).contains { !visited.contains($0) }
                snapshot("Back up to " + current + "." + (more ? " Try its next neighbour." : " Nothing new here either."), focus: current)
            }
            path.removeLast()
        }

        visit("A")
        frames.append(SimFrame(
            "Done. DFS visited " + order.joined(separator: ", ") + ": it went deep down one branch before touching C.",
            graphScene(g, done: visited, waiting: [], focus: nil, used: used, footer: "Order: " + order.joined(separator: " "))
        ))
        return Simulation(id: "dfs", title: "Depth-first", blurb: "Go deep first, backtrack when stuck.", frames: frames)
    }

    // MARK: Trees

    static func bstInsert() -> Simulation {
        let values = [50, 30, 70, 20, 40, 60, 80, 35]
        let sorted = values.sorted()
        var left: [Int: Int] = [:]
        var right: [Int: Int] = [:]
        var depth: [Int: Int] = [:]
        var parent: [Int: Int] = [:]
        var inserted: [Int] = []
        var root: Int?

        func scene(focus: Int?, fresh: Int?, footer: String) -> SimScene {
            var nodes: [GraphScene.Node] = []
            for value in inserted {
                let rank = sorted.firstIndex(of: value) ?? 0
                let x = 0.06 + 0.88 * (Double(rank) + 0.5) / Double(sorted.count)
                let y = 0.12 + Double(depth[value] ?? 0) * 0.24
                var mark: Mark = .idle
                if value == fresh { mark = .fresh }
                if value == focus { mark = .focus }
                nodes.append(GraphScene.Node(id: String(value), label: String(value), x: x, y: y, mark: mark))
            }
            var edges: [GraphScene.Edge] = []
            for value in inserted {
                if let p = parent[value] { edges.append(GraphScene.Edge(from: String(p), to: String(value))) }
            }
            return .graph(GraphScene(nodes: nodes, edges: edges, directed: true, footer: footer))
        }

        var frames: [SimFrame] = []
        for value in values {
            let footer = "Inserting " + String(value)
            guard var current = root else {
                root = value
                depth[value] = 0
                inserted.append(value)
                frames.append(SimFrame(String(value) + " becomes the root. Rule: smaller values go left, larger go right.", scene(focus: nil, fresh: value, footer: footer)))
                continue
            }
            while true {
                let goLeft = value < current
                let side = goLeft ? "left" : "right"
                let compare = goLeft ? " < " : " > "
                frames.append(SimFrame(String(value) + compare + String(current) + ", so go " + side + ".", scene(focus: current, fresh: nil, footer: footer)))
                let child = goLeft ? left[current] : right[current]
                if let child {
                    current = child
                    continue
                }
                if goLeft { left[current] = value } else { right[current] = value }
                parent[value] = current
                depth[value] = (depth[current] ?? 0) + 1
                inserted.append(value)
                frames.append(SimFrame("Empty spot: " + String(value) + " becomes the " + side + " child of " + String(current) + ".", scene(focus: nil, fresh: value, footer: footer)))
                break
            }
        }
        let inOrder = sorted.map { String($0) }.joined(separator: " ")
        frames.append(SimFrame("Read left, node, right and you get them in order: " + inOrder + ". Each insert walked one path, not the whole tree.", scene(focus: nil, fresh: nil, footer: "In order: " + inOrder)))
        return Simulation(id: "bstInsert", title: "Building a search tree", blurb: "Inserting values by going left or right.", frames: frames)
    }

    static func heapPosition(_ index: Int) -> Point2 {
        var depth = 0
        while (1 << (depth + 1)) - 1 <= index { depth += 1 }
        let first = (1 << depth) - 1
        let count = 1 << depth
        let x = (Double(index - first) + 0.5) / Double(count)
        return Point2(0.05 + 0.9 * x, 0.14 + Double(depth) * 0.3)
    }

    static func heapInsert() -> Simulation {
        var heap: [Int] = []

        func scene(_ marks: [Int: Mark]) -> SimScene {
            var nodes: [GraphScene.Node] = []
            for i in heap.indices {
                let p = heapPosition(i)
                nodes.append(GraphScene.Node(id: "i" + String(i), label: String(heap[i]), x: p.x, y: p.y, mark: marks[i] ?? .idle))
            }
            var edges: [GraphScene.Edge] = []
            for i in heap.indices where i > 0 {
                edges.append(GraphScene.Edge(from: "i" + String((i - 1) / 2), to: "i" + String(i)))
            }
            let array = "Array: [" + heap.map { String($0) }.joined(separator: ", ") + "]"
            return .graph(GraphScene(nodes: nodes, edges: edges, footer: array))
        }

        var frames: [SimFrame] = []
        for value in [5, 3, 8, 1, 6, 2] {
            heap.append(value)
            var i = heap.count - 1
            let where_ = i == 0 ? "It becomes the top." : "It goes in the next free spot."
            frames.append(SimFrame("Insert " + String(value) + ". " + where_, scene([i: .fresh])))
            while i > 0 {
                let p = (i - 1) / 2
                if heap[i] < heap[p] {
                    frames.append(SimFrame(String(heap[i]) + " is smaller than its parent " + String(heap[p]) + ", so they swap.", scene([i: .focus, p: .compare])))
                    heap.swapAt(i, p)
                    i = p
                } else {
                    frames.append(SimFrame(String(heap[i]) + " is not smaller than its parent " + String(heap[p]) + ", so it stays.", scene([i: .done, p: .compare])))
                    break
                }
            }
            if i == 0 && heap.count > 1 {
                frames.append(SimFrame(String(heap[0]) + " reached the top: it's the new smallest.", scene([0: .done])))
            }
        }
        frames.append(SimFrame("The smallest value, " + String(heap[0]) + ", is always on top, ready to be taken first. Each insert climbed at most a few levels.", scene([0: .done])))
        return Simulation(id: "heapInsert", title: "Min-heap inserts", blurb: "New values bubble up until their parent is smaller.", frames: frames)
    }

    // MARK: Shortest paths

    static func dijkstra() -> Simulation {
        let order = ["S", "A", "B", "C", "D", "T"]
        let positions: [String: Point2] = [
            "S": Point2(0.08, 0.5), "A": Point2(0.36, 0.16), "B": Point2(0.36, 0.84),
            "C": Point2(0.66, 0.16), "D": Point2(0.66, 0.84), "T": Point2(0.92, 0.5),
        ]
        let roads: [(String, String, Int)] = [
            ("S", "A", 4), ("S", "B", 1), ("A", "B", 2), ("A", "C", 5),
            ("B", "D", 8), ("C", "D", 1), ("C", "T", 3), ("D", "T", 6),
        ]
        var dist: [String: Int] = ["S": 0]
        var prev: [String: String] = [:]
        var done: Set<String> = []

        func neighbours(_ id: String) -> [(String, Int)] {
            var result: [(String, Int)] = []
            for (a, b, w) in roads {
                if a == id { result.append((b, w)) }
                if b == id { result.append((a, w)) }
            }
            return result.sorted { $0.0 < $1.0 }
        }

        func label(_ id: String) -> String {
            dist[id].map { String($0) } ?? "∞"
        }

        func scene(focus: String?, fresh: String? = nil, road: (String, String)? = nil, route: Set<String> = []) -> SimScene {
            var nodes: [GraphScene.Node] = []
            for id in order {
                var mark: Mark = done.contains(id) ? .done : .idle
                if id == fresh { mark = .fresh }
                if id == focus { mark = .focus }
                let p = positions[id]!
                nodes.append(GraphScene.Node(id: id, label: id, x: p.x, y: p.y, mark: mark, badge: label(id)))
            }
            var edges: [GraphScene.Edge] = []
            for (a, b, w) in roads {
                var mark: Mark = route.contains(DemoGraph.key(a, b)) ? .done : .idle
                if let road, DemoGraph.key(road.0, road.1) == DemoGraph.key(a, b) { mark = .compare }
                edges.append(GraphScene.Edge(from: a, to: b, label: String(w), mark: mark))
            }
            return .graph(GraphScene(nodes: nodes, edges: edges, footer: "Badges show the best known distance from S"))
        }

        var frames = [SimFrame("Find the cheapest route from S to everywhere. S is 0 away; every other distance starts unknown (∞).", scene(focus: nil))]
        while done.count < order.count {
            let open = order.filter { !done.contains($0) && dist[$0] != nil }
            guard var current = open.first else { break }
            for id in open where dist[id]! < dist[current]! { current = id }
            done.insert(current)
            frames.append(SimFrame("The closest unfinished place is " + current + ", at " + label(current) + ". That distance is now final.", scene(focus: current)))
            for (next, weight) in neighbours(current) where !done.contains(next) {
                let base = dist[current]!
                let candidate = base + weight
                let sum = current + " → " + next + ": " + String(base) + " + " + String(weight) + " = " + String(candidate)
                if let known = dist[next], known <= candidate {
                    frames.append(SimFrame(sum + ", no better than " + String(known) + ". Keep " + String(known) + ".", scene(focus: current, road: (current, next))))
                } else {
                    let old = label(next)
                    dist[next] = candidate
                    prev[next] = current
                    frames.append(SimFrame(sum + ", better than " + old + ". Update " + next + ".", scene(focus: current, fresh: next, road: (current, next))))
                }
            }
        }
        var route: Set<String> = []
        var stops = ["T"]
        while let up = prev[stops[stops.count - 1]] {
            route.insert(DemoGraph.key(up, stops[stops.count - 1]))
            stops.append(up)
        }
        let routeText = stops.reversed().joined(separator: " → ")
        frames.append(SimFrame("Cheapest route: " + routeText + ", total " + label("T") + ". The direct road S–A costs 4 but isn't on it: going via B is cheaper.", scene(focus: nil, route: route)))
        return Simulation(id: "dijkstra", title: "Dijkstra's algorithm", blurb: "Always finish the closest place next.", frames: frames)
    }

    // MARK: Dynamic programming and recursion

    static func fibTable() -> Simulation {
        var f = [0, 1]

        func scene(fresh: Set<Int>, compare: Set<Int>) -> SimScene {
            var cells: [SimCell] = []
            for i in 0...10 {
                let text = i < f.count ? String(f[i]) : ""
                var mark: Mark = i < f.count ? .done : .idle
                if compare.contains(i) { mark = .compare }
                if fresh.contains(i) { mark = .fresh }
                cells.append(SimCell(text, mark, note: "f(" + String(i) + ")"))
            }
            return .array(ArrayScene(cells: cells))
        }

        var frames = [SimFrame("Base cases: f(0) = 0 and f(1) = 1. Every later value is the sum of the two before it.", scene(fresh: [0, 1], compare: []))]
        for i in 2...10 {
            f.append(f[i - 1] + f[i - 2])
            let caption = "f(" + String(i) + ") = f(" + String(i - 1) + ") + f(" + String(i - 2) + ") = " + String(f[i - 1]) + " + " + String(f[i - 2]) + " = " + String(f[i]) + ". Both were already in the table."
            frames.append(SimFrame(caption, scene(fresh: [i], compare: [i - 1, i - 2])))
        }
        frames.append(SimFrame("f(10) = 55 after just 9 additions. Plain recursion, which forgets its answers, would make 177 calls.", scene(fresh: [], compare: [])))
        return Simulation(id: "fibTable", title: "Filling the table", blurb: "Fibonacci with every answer stored once.", frames: frames)
    }

    static func factorialStack() -> Simulation {
        var stack: [SimCell] = []

        func scene(out: String?) -> SimScene {
            let markers = stack.isEmpty ? [] : [SimMarker(stack.count - 1, "running")]
            return .array(ArrayScene(cells: stack, markers: markers, vertical: true, label: out))
        }

        var frames: [SimFrame] = []
        for n in stride(from: 4, through: 1, by: -1) {
            for i in stack.indices { stack[i].mark = .idle }
            if n == 1 {
                stack.append(SimCell("factorial(1)", .fresh, note: "base case: 1"))
                frames.append(SimFrame("factorial(1) is the base case: it returns 1 straight away, no further calls.", scene(out: nil)))
            } else {
                stack.append(SimCell("factorial(" + String(n) + ")", .fresh, note: String(n) + " × factorial(" + String(n - 1) + ")"))
                let lead = n == 4 ? "Call factorial(4). " : "Call factorial(" + String(n) + "). "
                frames.append(SimFrame(lead + "It needs factorial(" + String(n - 1) + ") first, so it waits on the stack.", scene(out: nil)))
            }
        }
        var result = 1
        for n in 2...4 {
            stack.removeLast()
            let previous = result
            result *= n
            stack[stack.count - 1].mark = .focus
            stack[stack.count - 1].note = String(n) + " × " + String(previous) + " = " + String(result)
            frames.append(SimFrame("factorial(" + String(n - 1) + ") returns " + String(previous) + " and its frame is popped. factorial(" + String(n) + ") resumes: " + String(n) + " × " + String(previous) + " = " + String(result) + ".", scene(out: "Returned " + String(previous))))
        }
        stack.removeLast()
        frames.append(SimFrame("factorial(4) returns 24 and the stack is empty again. Each call waited in its own frame until the one above it finished.", scene(out: "Result: 24")))
        return Simulation(id: "factorialStack", title: "factorial(4) on the call stack", blurb: "Calls pile up, then unwind with answers.", frames: frames)
    }

    // MARK: Calculus and growth

    static func samples(_ range: ClosedRange<Double>, step: Double, _ f: (Double) -> Double) -> [Point2] {
        stride(from: range.lowerBound, through: range.upperBound + step / 2, by: step).map { Point2($0, f($0)) }
    }

    static func descent(id: String, title: String, rate: Double, steps: Int, blurb: String, outro: String) -> Simulation {
        let f: (Double) -> Double = { x in 0.5 * (x - 1) * (x - 1) + 0.5 }
        let slope: (Double) -> Double = { x in x - 1 }
        let curve = CurveScene.Curve(label: "error", points: samples(-4...6, step: 0.1, f))
        var x = -3.0
        var trail: [Point2] = []

        func scene() -> SimScene {
            .curve(CurveScene(curves: [curve], xRange: -4...6, yRange: 0...13, point: Point2(x, f(x)), trail: trail, tangentSlope: slope(x)))
        }

        var frames = [SimFrame("Start at x = −3. The goal is the lowest point of the curve. The line shows the slope where you stand. Learning rate: " + fmt(rate) + ".", scene())]
        for k in 1...steps {
            let s = slope(x)
            let next = x - rate * s
            trail.append(Point2(x, f(x)))
            let caption = "Step " + String(k) + ": slope at x = " + fmt(x) + " is " + fmt(s) + ". Move to x − " + fmt(rate) + " × " + fmt(s) + " = " + fmt(next) + "."
            x = next
            frames.append(SimFrame(caption, scene()))
        }
        frames.append(SimFrame(outro, scene()))
        return Simulation(id: id, title: title, blurb: blurb, frames: frames)
    }

    static func secantTangent() -> Simulation {
        let f: (Double) -> Double = { x in 0.25 * x * x }
        let curve = CurveScene.Curve(label: "x²/4", points: samples(-1...5, step: 0.1, f))
        let anchor = Point2(2, f(2))
        var frames: [SimFrame] = []
        for (i, h) in [2.0, 1.0, 0.5, 0.1].enumerated() {
            let other = Point2(2 + h, f(2 + h))
            let slope = (other.y - anchor.y) / h
            var caption = "Gap h = " + fmt(h) + ": the slope between the two points is (f(2 + h) − f(2)) / h = " + fmt(slope, 3) + "."
            if i == 0 {
                caption = "A curve's steepness keeps changing, so measure it between two points. " + caption
            }
            frames.append(SimFrame(caption, .curve(CurveScene(curves: [curve], xRange: -1...5, yRange: -0.5...6.5, point: anchor, secondPoint: other))))
        }
        frames.append(SimFrame(
            "Shrink the gap to nothing and the slope settles at exactly 1. That limit is the derivative of x²/4 at x = 2: the tangent line.",
            .curve(CurveScene(curves: [curve], xRange: -1...5, yRange: -0.5...6.5, point: anchor, tangentSlope: 1))
        ))
        return Simulation(id: "secantTangent", title: "From secant to tangent", blurb: "Watch a slope between two points become a slope at one point.", frames: frames)
    }

    static func growthCurves() -> Simulation {
        let range = 1.0...16.0
        let all: [CurveScene.Curve] = [
            CurveScene.Curve(label: "n", points: samples(range, step: 0.25) { $0 }),
            CurveScene.Curve(label: "log n", points: samples(range, step: 0.25) { log2($0) }),
            CurveScene.Curve(label: "n log n", points: samples(range, step: 0.25) { $0 * log2($0) }),
            CurveScene.Curve(label: "n²", points: samples(range, step: 0.25) { $0 * $0 }),
        ]
        let captions = [
            "O(n): double the input, double the work. Reading every item once looks like this.",
            "O(log n): barely grows. 16 items need only 4 halvings; a million need about 20.",
            "O(n log n): a little more than linear. Good sorting algorithms live here.",
            "O(n²): every pair. 16 items already mean 256 steps, far off the top of the chart.",
        ]
        var frames: [SimFrame] = []
        for count in 1...all.count {
            var shown = Array(all.prefix(count))
            for i in shown.indices { shown[i].mark = i == count - 1 ? .focus : .idle }
            frames.append(SimFrame(captions[count - 1], .curve(CurveScene(curves: shown, xRange: range, yRange: 0...40))))
        }
        frames.append(SimFrame(
            "At a million items: log n is about 20 steps, n log n about 20 million, and n² a trillion. Growth rate beats raw speed.",
            .curve(CurveScene(curves: all, xRange: range, yRange: 0...40))
        ))
        return Simulation(id: "growthCurves", title: "How work grows", blurb: "Four growth rates on one chart.", frames: frames)
    }
}
