//
//  clockWidgetBundle.swift
//  clockWidget
//
//  Created by Reswin Kandathil on 3/17/26.
//

import WidgetKit
import SwiftUI

@main
struct clockWidgetBundle: WidgetBundle {
    var body: some Widget {
        clockWidget()
        largeClockWidget()
        lockscreenClockWidget()
        clockWidgetControl()
        clockWidgetLiveActivity()
    }
}
