//
//  ProjectView.swift
//  CPM_Graphic
//
//  Created by 김형관 on 2/20/25.
//  Edited by Team10 on 5/21/25.
//
import SwiftData
import SwiftUI

struct ProjectView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: [
        SortDescriptor(\Activity.id),
        SortDescriptor(\Activity.name)
    ]) var activities: [Activity]
    @Binding var startDateInput : String

    var body: some View {
        VStack {
            TextField("Start Date", text: $startDateInput)
                .keyboardType(.numberPad)
                .padding()
            List {
                ForEach(activities) { activity in
                    NavigationLink(value: activity) {
                        Text("ID: \(activity.id), Name: \(activity.name)")
                    }
                }
                .onDelete(perform: deleteActivity)
            }
        }
    }

    func deleteActivity (at offsets: IndexSet) {
        for offset in offsets {
            let activity = activities[offset]
            modelContext.delete(activity)
        }
    }
}

struct ProjectResultView: View {
    let resultString: String
    @State private var isShowingGraphicalResults = false // State to manage presentation
    @StateObject var activityPositions = ActivityPositions() // Defined in the parent view

    var body: some View {
        ScrollView {
            Text(resultString)
                .padding()

            Button("Show Graphical View") {
                isShowingGraphicalResults = true
            }
            .sheet(isPresented: $isShowingGraphicalResults) {
                GraphicalResultView() // The view to show in a modal sheet
                    .environmentObject(activityPositions) // Provide the instance here
            }
        }
        .navigationTitle("Project Results")
    }
}

struct GraphicalResultView: View {
    @Query(sort: [
        SortDescriptor(\Activity.id),
        SortDescriptor(\Activity.name)
    ]) var activities: [Activity]
    @EnvironmentObject var activityPositions: ActivityPositions
    @State private var showOnlyCritical = false // State to toggle critical path filter

    // Function to group and sort activities by `earlyStart`
    private func groupedAndSortedActivities() -> [[Activity]] {
        let filtered = showOnlyCritical ? activities.filter { $0.totalFloat == 0 } : activities
        let grouped = Dictionary(grouping: filtered) { $0.earlyStart }
        return grouped.sorted { $0.key < $1.key }.map { $0.value }
    }

    var body: some View {
        ScrollView {
            // Put the blocks and the arrow overlay
            // together in a ZStack:
            Toggle("Show Only Critical Path", isOn: $showOnlyCritical)
                .padding(.horizontal)
            ZStack(alignment: .topLeading) {
                // The block layout
                VStack {
                    ForEach(groupedAndSortedActivities(), id: \.self) { activityGroup in
                        HStack(spacing: 10) {
                            ForEach(activityGroup, id: \.id) { activity in
                                ActivityBlockView(activity: activity)
                            }
                        }
                    }
                }
                .padding()
                // The arrow overlay
                ArrowOverlay()
            }
            // Name this coordinate space "ChartSpace"
            .coordinateSpace(name: "ChartSpace")
        }
    }
}

struct ActivityBlockView: View {
    var activity: Activity
    @EnvironmentObject var activityPositions: ActivityPositions

    var body: some View {
        Rectangle()
            .fill(activity.totalFloat == 0 ? Color.red : Color.blue)
            .frame(width: 90, height: 120)
            .overlay(
                VStack {
                    Text("\(activity.name)   Du: \(activity.duration)")
                    HStack {
                        Text("ES: \(activity.earlyStart)")
                        Text("EF: \(activity.earlyFinish)")
                    }
                    HStack {
                        Text("LS: \(activity.lateStart)")
                        Text("LF: \(activity.lateFinish)")
                    }
                }
                .foregroundColor(.white)
            )
            // Use GeometryReader to record the view's position
            // in the *named* coordinate space you declared above
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        let frame = geometry.frame(in: .named("ChartSpace"))
                        let topCenter = CGPoint(x: frame.midX, y: frame.minY)
                        let bottomCenter = CGPoint(x: frame.midX, y: frame.maxY)
                        activityPositions.updatePosition(
                            for: activity.id,
                            top: topCenter,
                            bottom: bottomCenter
                        )
                    }
            })
            .padding(.vertical)
    }
}

class ActivityPositions: ObservableObject {
    // Maps Activity ID to its rectangle's top and bottom center positions
    @Published var positions: [Int: (top: CGPoint, bottom: CGPoint)] = [:]

    func updatePosition(for id: Int, top: CGPoint, bottom: CGPoint) {
        positions[id] = (top, bottom)
    }

    func position(for id: Int) -> (top: CGPoint, bottom: CGPoint)? {
        return positions[id]
    }
}

struct ArrowOverlay: View {
    @EnvironmentObject var activityPositions: ActivityPositions
    @Query(sort: [
        SortDescriptor(\Activity.id),
        SortDescriptor(\Activity.name)
    ]) var activities: [Activity]

    var body: some View {
        Canvas { context, size in
            for activity in activities {
                guard let positions = activityPositions.position(for: activity.id) else { continue }
                for successor in activity.successors {
                    guard let successorPositions = activityPositions.position(for: successor.id) else { continue }
                    drawArrow(from: positions.bottom, to: successorPositions.top, in: context)
                }
            }
        }
    }

    func drawArrow(from start: CGPoint, to end: CGPoint, in context: GraphicsContext) {
        // Calculate the main line of the arrow from start to end
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        // Define the arrowhead size and angles
        let arrowHeadLength: CGFloat = 15
        let arrowHeadAngle: CGFloat = .pi / 6  // 30 degrees

        // Calculate the angle of the arrow
        let angle = atan2(end.y - start.y, end.x - start.x)

        // Calculate points for the arrowhead
        let arrowPoint1 = CGPoint(
            x: end.x - arrowHeadLength * cos(angle + arrowHeadAngle),
            y: end.y - arrowHeadLength * sin(angle + arrowHeadAngle)
        )
        let arrowPoint2 = CGPoint(
            x: end.x - arrowHeadLength * cos(angle - arrowHeadAngle),
            y: end.y - arrowHeadLength * sin(angle - arrowHeadAngle)
        )

        // Draw the line of the arrow
        context.stroke(path, with: .color(.black), lineWidth: 2)

        // Draw the arrowhead
        var arrowHead = Path()
        arrowHead.move(to: end)
        arrowHead.addLine(to: arrowPoint1)
        arrowHead.addLine(to: arrowPoint2)
        arrowHead.addLine(to: end)
        arrowHead.closeSubpath()

        // Fill the arrowhead
        context.fill(arrowHead, with: .color(.black))
    }
}
