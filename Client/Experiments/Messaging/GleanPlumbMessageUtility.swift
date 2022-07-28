// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

import MozillaAppServices
import Shared

private let log = Logger.syncLogger
/// Methods here can be considered as tools for extracting certain information from a message.
class GleanPlumbMessageUtility: Loggable {

    // MARK: - Properties

    /// Holds evaluations of JEXLS seen so far.
    var jexlMap: [String: Bool] = [:]

    // MARK: - Public helpers

    func createGleanPlumbHelper() -> GleanPlumbMessageHelper? {
        let contextProvider = GleanPlumbContextProvider()

        /// Create our GleanPlumbMessageHelper.
        do {
            return try Experiments.shared.createMessageHelper(additionalContext: contextProvider.createAdditionalDeviceContext())
        } catch {
            log.debug("DEBUG - createGleanPlumbHelper with error \(error)")
            /// If we're here, then all of Messaging is in limbo! Report the error and let the surface handle this `nil`
            browserLog.error("GleanPlumbMessageHelper could not be created! With error \(error)")
            return nil
        }
    }

    /// We check whether this message is triggered by evaluating message JEXLs.
    func isMessageEligible(_ message: GleanPlumbMessage, messageHelper: GleanPlumbMessageHelper) throws -> Bool {

        return try message.triggers.reduce(true) { accumulator, trigger in
            guard accumulator else {
                log.debug("DEBUG - GleanPlumbMessageUtility accumulator \(accumulator) for trigger \(trigger)")
                return false
            }
            var isTriggered: Bool

            // Check the jexlMap for the `Bool`, in the case we already evaluated it.
            if jexlMap[trigger] != nil, let jexlEvaluation = jexlMap[trigger] {
                log.debug("DEBUG - GleanPlumbMessageUtility if \(jexlEvaluation)")
                isTriggered = jexlEvaluation
            } else {
                // Otherwise, perform this expensive Foreign Function Interface operation once for the trigger.
                log.debug("DEBUG - GleanPlumbMessageUtility else \(trigger)")
                isTriggered = try messageHelper.evalJexl(expression: trigger)
                log.debug("DEBUG - GleanPlumbMessageUtility isTriggered \(isTriggered)")
                jexlMap[trigger] = isTriggered
            }

            return isTriggered
        }
    }

}
