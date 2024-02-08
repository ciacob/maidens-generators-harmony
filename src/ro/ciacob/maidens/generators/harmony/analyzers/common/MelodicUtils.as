package ro.ciacob.maidens.generators.harmony.analyzers.common {
import ro.ciacob.maidens.generators.core.interfaces.IMusicPitch;
import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
import ro.ciacob.math.Fraction;
import ro.ciacob.math.IFraction;

public class MelodicUtils {
    public function MelodicUtils() {
    }

    /**
     * Returns the top-most MIDI pitch of a given music unit, or `0` if the unit is empty.
     * @param   unit
     *          A MusicUnit to find the top-most pitch of.
     * @return  The top-most MIDI pitch as an unsigned integer.
     */
    public static function getTopPitchOf (unit : IMusicUnit) : uint {
        var pitch : IMusicPitch;
        var midiNumber : uint;
        var j : int = 0;
        var topMidiNumber : uint = 0;
        var pitches : Vector.<IMusicPitch> = unit.pitches;
        var numPitches : uint = pitches.length;
        for (j; j < numPitches; j++) {
            pitch = pitches[j];
            midiNumber = pitch.midiNote;
            if (midiNumber > topMidiNumber) {
                topMidiNumber = midiNumber;
            }
        }
        return topMidiNumber;
    }
    /**
     * Computes and returns the average/"pivot" pitch of the given `units`, along with some other side info.
     *
     * @param   musicalFragment
     *          A Vector of IMusicUnit items (contains both pitch and duration information) to be melodically analyzed.
     *
     * @param   weighInDuration
     *          Whether to factor-in the cumulated duration of each pitch. If true (the default), the
     *          average note duration for the entire fragment span will be calculated, and the duration of each unit
     *          will be divided by that in order to produce the weight to use.
     *
     * @return  An Object with details of the analysis. The following information is returned:
     *
     *          - 'averageDuration' : Average note duration for the entire fragment, as a Fraction;
     *
     *          - 'direction': `1`, `-1` or `0`, if the fragment melodically ascends, descends or has no clear direction;
     *
     *          - 'markerPitch': First pitch in the top voice/layer of the fragment;
     *
     *          - 'pivotPitchInterval': the number of semitones that separates `markerPitch` from the calculated
     *                                  average (aka "pivot") of the fragment's range. The average can be weighted or
     *                                  not, based on the `weighInDuration` parameter.
     *
     *          - 'pivotPitch' : the MIDI number obtained by adding `markerPitch` to `pivotPitchInterval`;
     *
     *          - 'mirroredPivotPitch' : the MIDI number obtained by subtracting `pivotPitchInterval` from `markerPitch`;
     *
     *          - 'highestPitchInFragment': the highest of the MIDI pitches found in the top voice/layer of the fragment;
     *
     *          - 'lowestPitchInFragment': the lowest of the MIDI pitches found in the top voice/layer of the fragment;
     *
     *          - 'fragmentRange': the number of semitones representing the range of the top voice/layer of the fragment
     *                             (i.e., `lowestPitchInFragment` subtracted from `highestPitchInFragment`).
     */

    public static function analyzeMelodicProfile (musicalFragment : Vector.<IMusicUnit>,
                                                  weighInDuration : Boolean = true) : Object {


        // Obtain a "pitch table", where each pitch in use (or only the op-most, if requested) is
        // listed just once, along with its total duration.
        var highestPitchInFragment : uint = 0;
        var lowestPitchInFragment : uint = 127;
        var pitchTable : Object = {};
        var markerPitch : uint = 0;
        var durationsCount : uint = 0;
        var durationsSum : IFraction = Fraction.ZERO;
        var averageDuration : IFraction;
        for  (var i : int = 0; i < musicalFragment.length; i++) {
            var unit : IMusicUnit = musicalFragment[i];
            var unitDuration : IFraction = unit.duration;
            var pitches : Vector.<IMusicPitch> = unit.pitches;
            var unitHasPitches : Boolean = false;
            var topUnitPitch : uint = 0;
            for (var j : int = 0; j < pitches.length; j++) {
                var pitch : IMusicPitch = pitches[j];
                var midiNumber : uint = pitch.midiNote;

                // IMusicPitch instances having a `midiNote` of `0` are rests and must be ignored.
                if (midiNumber > 0) {
                    unitHasPitches = true;
                    if (midiNumber > topUnitPitch) {
                        topUnitPitch = midiNumber;
                    }
                }
            }
            if (unitHasPitches) {

                // We work towards computing `averageDuration` by counting every "non-rest" unit and adding it duration.
                durationsCount++;
                durationsSum = durationsSum.add (unitDuration);

                // We found the top-most pitch of the current unit: we update the pitchTable with it.
                if (!(topUnitPitch in pitchTable)) {
                    pitchTable[topUnitPitch] = unitDuration;
                } else {
                    var storedDuration : IFraction = (pitchTable[topUnitPitch] as IFraction);
                    pitchTable[topUnitPitch] = storedDuration.add (unitDuration);
                }

                // Also, we need to get a hold on the first pitch of the first unit
                if (!markerPitch) {
                    markerPitch = topUnitPitch;
                }

                // Finally, we want to get a hold on the highest and lowest pitches for the entire fragment.
                if (topUnitPitch > highestPitchInFragment) {
                    highestPitchInFragment = topUnitPitch;
                }
                if (topUnitPitch < lowestPitchInFragment) {
                    lowestPitchInFragment = topUnitPitch;
                }
            }
        }

        // We actually compute the average duration
        averageDuration = durationsSum.divide(new Fraction(durationsCount));

        // We compute the pivot/center pitch by weighting-in the duration or not, as requested.
        var operand : Number;
        var denominator : uint = 0;
        var pitchIntervalsSum : Number = 0;
        for (var key : String in pitchTable) {
            var midiPitch : uint = parseInt(key);
            var pitchInterval : int = (midiPitch - markerPitch);
            var durationFraction : IFraction = (pitchTable[key] as IFraction);

            // If requested, we weight pitches by the ratio of their duration to the average duration.
            if (weighInDuration) {
                var weight : Number = durationFraction.divide(averageDuration).floatValue;
                operand = (pitchInterval * weight);
            } else {
                operand = pitchInterval;
            }
            pitchIntervalsSum += operand;
            denominator++;
        }
        var pivotPitchInterval : int = Math.round (pitchIntervalsSum / denominator);
        var pivotPitch : uint = (markerPitch + pivotPitchInterval);
        var mirroredPivotPitch : int = (markerPitch - pivotPitchInterval);

        // We compute the fragment's ambitus/range and return as side info.
        var fragmentRange : uint = (highestPitchInFragment && lowestPitchInFragment)?
                highestPitchInFragment - lowestPitchInFragment : 0;

        return {
            'averageDuration' : averageDuration,
            'direction': (pivotPitchInterval > 0) ? 1 : (pivotPitchInterval < 0) ? -1 : 0,
            'markerPitch': markerPitch,
            'mirroredPivotPitch' : mirroredPivotPitch,
            'pivotPitch' : pivotPitch,
            'pivotPitchInterval': pivotPitchInterval,
            'highestPitchInFragment': highestPitchInFragment,
            'lowestPitchInFragment': lowestPitchInFragment,
            'fragmentRange': fragmentRange
        };
    }
}
}
