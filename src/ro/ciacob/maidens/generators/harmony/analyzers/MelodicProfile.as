package ro.ciacob.maidens.generators.harmony.analyzers {
import ro.ciacob.maidens.generators.core.abstracts.AbstractContentAnalyzer;
import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
import ro.ciacob.maidens.generators.core.interfaces.IMusicalContentAnalyzer;
import ro.ciacob.maidens.generators.core.interfaces.IParameter;
import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
import ro.ciacob.maidens.generators.core.interfaces.ISettingsList;
import ro.ciacob.maidens.generators.harmony.analyzers.common.MelodicUtils;
import ro.ciacob.maidens.generators.harmony.constants.ParameterCommons;
import ro.ciacob.maidens.generators.harmony.constants.ParameterNames;
import ro.ciacob.math.Fraction;
import ro.ciacob.math.IFraction;

public class MelodicProfile extends AbstractContentAnalyzer implements IMusicalContentAnalyzer {

    private static const WRONG_DIRECTION_PENALTY:Number = 0.25;
    private static const REPEATED_NOTE_PENALTY:Number = 0.1;
    private static const REPEATED_EDGE_PENALTY:Number = 0.07;

    /**
     * @constructor
     */
    public function MelodicProfile() {
        super(this);
    }

    /**
     * @see IMusicalContentAnalyzer.weight
     */
    override public function get weight():Number {
        return 0.99;
    }

    /**
     * @see IMusicalContentAnalyzer.name
     */
    override public function get name():String {
        return ParameterNames.MELODIC_DIRECTION_BALANCE;
    }

    /**
     * Analyzes the appropriateness of the top-most voice in the current IMusic instance, within the current
     * analysis context.
     *
     * @param targetMusicUnit
     * @param analysisContext
     * @param parameters
     * @param request
     */
    override public function analyze(targetMusicUnit:IMusicUnit, analysisContext:IAnalysisContext,
                                     parameters:IParametersList, request:IMusicRequest):void {

        // Bypass analysis if "Use melodic model" is off.
        var settings:ISettingsList = request.userSettings;
        var melodicSwitchParam:IParameter = parameters.getByName(ParameterNames.USE_MELODIC_MODEL)[0];
        var useMelodicModel:Boolean = !!(settings.getValueAt(melodicSwitchParam, 0) as uint);
        if (!useMelodicModel) {
            targetMusicUnit.analysisScores.add(ParameterNames.MELODIC_DIRECTION_BALANCE,
                    ParameterCommons.NA_RESERVED_VALUE);
            return;
        }

        // Remove rests from structures and trim empty structures from beginning and end of the "previousContent".
        // Bypass analysis if there is no "previous content" to this point (e.g., beginning of the generated
        // material), or it only contains rests.
        var prevContent:Vector.<IMusicUnit> = analysisContext.previousContent;

        // Compute the pitch that would "ideally" continue the given context, and represent the score of the
        // analysis as the smallest ratio between that pitch and the current pitch.
        var currentPitch:uint = MelodicUtils.getTopPitchOf(targetMusicUnit);
        var analysisResult:Object = MelodicUtils.analyzeMelodicProfile(prevContent);
        var originalPivotPitch:uint = analysisResult.pivotPitch;
        var idealDirection:int = (analysisResult.direction * -1) as int;
        var idealPitch:uint = (analysisResult.mirroredPivotPitch as uint);
        var actualDirection:int = (currentPitch > originalPivotPitch) ? 1 : (currentPitch < originalPivotPitch) ? -1 : 0;
        var ratio:IFraction = new Fraction(currentPitch, idealPitch);
        if (ratio.greaterThan(Fraction.WHOLE)) {
            ratio = ratio.reciprocal;
        }
        var score:Number = ratio.floatValue;
        var canonicalScore:uint = Math.round(score * 100);

        // Apply supplementary penalties if the current pitch takes the "wrong" direction.
        var penaltyOffset:Number;
        if (actualDirection != idealDirection) {
            penaltyOffset = (score * WRONG_DIRECTION_PENALTY);
            if (score > penaltyOffset) {
                score -= penaltyOffset;
                canonicalScore = Math.round(score * 100);
            }
        }

        // Apply supplementary penalties if the current pitch has already been used in the given context, the
        // more uses of it, the greater the penalty. This aimes to encourage more expressive melodic lines, and
        // should be an effective measure against long stretches of held or repeating pitches.
        var numAdjacentHeldNotes:uint = 0;
        for (var i:int = prevContent.length - 1; i >= 0; i--) {
            var pastPitch:uint = MelodicUtils.getTopPitchOf(prevContent[i]);
            if (pastPitch == 0) {
                continue;
            }
            if (pastPitch == currentPitch) {
                numAdjacentHeldNotes++;
                var penaltyFactor:Number = (numAdjacentHeldNotes * REPEATED_NOTE_PENALTY);
                penaltyOffset = (score * penaltyFactor);
                if (score > penaltyOffset) {
                    score -= penaltyOffset;
                    canonicalScore = Math.round(score * 100);
                }
            }
        }

        // Apply supplementary penalties if the current pitch is the highest or the lowest pitch recorded in the given
        // context. We are thus trying to encourage melodic lines that "lead" somewhere rather than closing onto themselves.
        // Also this should make for clearer climax points in our melody, which can only add to its comprehensibility.
        var highPastPitch:uint = analysisResult.highestPitchInFragment;
        var lowPastPitch:uint = analysisResult.lowestPitchInFragment;
        if ((highPastPitch != 0 && currentPitch == highPastPitch) ||
                (lowPastPitch != 127 && currentPitch == lowPastPitch)) {
            penaltyOffset = (score * REPEATED_EDGE_PENALTY);
            if (score > penaltyOffset) {
                score -= penaltyOffset;
                canonicalScore = Math.round(score * 100);
            }
        }

        // Commit the computed score to the unit.
        targetMusicUnit.analysisScores.add(ParameterNames.MELODIC_DIRECTION_BALANCE, canonicalScore);
    }
}
}
