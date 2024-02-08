package ro.ciacob.maidens.generators.harmony.sources {
import eu.claudius.iacob.music.knowledge.instruments.interfaces.IMusicalInstrument;

import flash.system.System;

import ro.ciacob.maidens.generators.constants.pitch.IntervalsSize;
import ro.ciacob.maidens.generators.core.MusicPitch;
import ro.ciacob.maidens.generators.core.MusicUnit;
import ro.ciacob.maidens.generators.core.PitchAllocation;
import ro.ciacob.maidens.generators.core.abstracts.AbstractRawMusicSource;
import ro.ciacob.maidens.generators.core.constants.CoreOperationKeys;
import ro.ciacob.maidens.generators.core.helpers.CommonMusicUtils;
import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
import ro.ciacob.maidens.generators.core.interfaces.IMusicPitch;
import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
import ro.ciacob.maidens.generators.core.interfaces.IParameter;
import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
import ro.ciacob.maidens.generators.core.interfaces.IPitchAllocation;
import ro.ciacob.maidens.generators.core.interfaces.IRawMusicSource;
import ro.ciacob.maidens.generators.core.interfaces.ISettingsList;
import ro.ciacob.maidens.generators.harmony.constants.ParameterNames;
import ro.ciacob.utils.Arrays;
import ro.ciacob.utils.Objects;

/**
 * Concrete IMusicalPrimitiveSource implementation that outputs one unique random chord
 * within given low and high thresholds.
 */
public class RandomChord extends AbstractRawMusicSource implements IRawMusicSource {

    private static const REFERENCE_NUM_MIN_INTERVALS:int = 2;

    // Class lifetime cache for the `_getAverageMiddleRange()` function
    private var _averageMiddleRange:Vector.<int>;

    // Storage for the value of the "VOICES_NUMBER" parameter.
    private var _totalNumVoices:int;

    // Storage for the value of the "HIGHEST_PITCH" parameter.
    private var _highestAvailablePitch:int;

    // Storage for the value of the "LOWEST_PITCH" parameter.
    private var _lowestAvailablePitch:int;

    // Storage for the value of the "INTRINSIC_CONSONANCE" parameter.
    private var _currentConsonance:int;

    // Storage for the value of the "ENFORCE_CONSONANCE" parameter.
    private var _enforceConsonance : Boolean;

    // Storage for rejected proposed chords to spare evaluating again.
    private var _rejectedChords:Object;

    /**
     * @constructor
     */
    public function RandomChord() {
        super(this);
    }

    /**
     * Note: delegates the actual work to method "_generateChord()".
     * @see IMusicalPrimitiveSource.output
     * @see _generateChord()
     * @see _isShallowChord()
     */
    override public function output(targetMusicUnit:IMusicUnit,
                                    analysisContext:IAnalysisContext,
                                    parameters:IParametersList,
                                    request:IMusicRequest):Vector.<IMusicUnit> {

        // Reset the storage for rejeccted chords, as parameters may change from chord to chord and, what was not
        // acceptable one chord ago may now be desirable.
        _rejectedChords = {};

        // Force garbage collection before generating every chord. If there is less to collect, it takes less time to
        // do it.
        System.pauseForGCIfCollectionImminent(0.0001);

        // Build and return one unique and not shallow random chord. It needs to be returned inside a Vector
        // for consistency with the Interface we are implementing.
        var payload:Vector.<IMusicUnit> = new Vector.<IMusicUnit>;
        var proposedChord:IMusicUnit;
        var signature:String;
        // var isConsonanceAcceptable : Boolean;
        var isDepthAcceptable : Boolean;
        _currentConsonance = _getCurrentConsonance(analysisContext, parameters, request);
        _enforceConsonance = _getEnforceConsonance(parameters, request);
        while ((proposedChord = _generateChord(targetMusicUnit, analysisContext, parameters, request))) {
            signature = proposedChord.pitches.toString();
            if (!_rejectedChords[signature]) {
                isDepthAcceptable = !_isShallowChord(proposedChord);
                if (isDepthAcceptable) {
                    break;
                } else {
                    _rejectedChords[signature] = true;
                }
            } else {
                // Used for debug.
            }
        }
        payload.push(proposedChord);
        return payload;
    }

    /**
     * Retrieves the current value of the "Intrinsic Consonance" parameter, as a Number between "0" and "1".
     * @param analysisContext
     * @param parameters
     * @param request
     * @return
     */
    private function _getCurrentConsonance(analysisContext:IAnalysisContext,
                                           parameters:IParametersList,
                                           request:IMusicRequest):uint {
        var percentTime:int = Math.round(analysisContext.percentTime * 100);
        var consonanceParam:IParameter = parameters.getByName(ParameterNames.INTRINSIC_CONSONANCE)[0];
        return (request.userSettings.getValueAt(consonanceParam, percentTime) as uint);
    }

    /**
     * Retrieves the value of the "Enforce Consonance" parameter, as a Boolean.
     * @param analysisContext
     * @param parameters
     * @param request
     * @return
     */
    private function _getEnforceConsonance(parameters:IParametersList,
                                           request:IMusicRequest):Boolean {
        var enforceConsonanceParam : IParameter = parameters.getByName(ParameterNames.ENFORCE_CONSONANCE)[0];
        return (request.userSettings.getValueAt(enforceConsonanceParam, 0) === 1);
    }

    /**
     * Resets local cache before class' end of life, in case this is needed.
     * @see IRawMusicSource.reset
     */
    override public function reset():void {
        _totalNumVoices = 0;
        _averageMiddleRange = null;
        _highestAvailablePitch = 0;
        _lowestAvailablePitch = 0;
    }

    /**
     * Actually does the job of creating a possible chord (only pitches are provided).
     * @param targetMusicUnit
     * @param analysisContext
     * @param parameters
     * @param request
     * @return A IMusicUnit implementor instance with the proposed pitches.
     * @see @see IMusicalPrimitiveSource.output
     */
    private function _generateChord(targetMusicUnit:IMusicUnit,
                                    analysisContext:IAnalysisContext,
                                    parameters:IParametersList,
                                    request:IMusicRequest):IMusicUnit {

        // GRAB CONTEXT
        var percentTime:int = Math.round(analysisContext.percentTime * 100);
        var getParam:Function = parameters.getByName;
        var settings:ISettingsList = request.userSettings;
        var instruments:Vector.<IMusicalInstrument> = request.instruments;

        // We need to internally reorder available instruments based on their center pitch, so that if we have e.g.,
        // brass ordered as  Horns, Trumpets, Trombone and Tuba (traditional score ordering) we are still able to
        // deliver the highest notes of a chord to Trumpets, then the mid and mid/low notes to Horns and, the low
        // notes to Trombones and Tuba, just as if the instruments were ordered as Trumpets, Horns, Trombones and
        // Tuba (contemporary score ordering).
        instruments = CommonMusicUtils.cloneAndReorderInstruments(instruments);

        // GRAB PARAMETERS' VALUES
        // Chord range
        var lowestParam:IParameter = getParam(ParameterNames.LOWEST_PITCH)[0];
        var lowestPercent:Number = ((settings.getValueAt(lowestParam, percentTime) as uint) * 0.01) as Number;
        var highestParam:IParameter = getParam(ParameterNames.HIGHEST_PITCH)[0];
        var highestPercent:Number = ((settings.getValueAt(highestParam, percentTime) as uint) * 0.01) as Number;
        var middleRange:Vector.<int> = _getAverageMiddleRange(instruments);
        var highestPitch:int = _getHighestAvailablePitch(instruments);
        var lowestPitch:int = _getLowestAvailablePitch(instruments);
        var highest:int = middleRange[1] + Math.round(highestPercent * (highestPitch - middleRange[1]));
        var lowest:int = lowestPitch + Math.round(lowestPercent * (middleRange[0] - lowestPitch));

        // Number of pitches in the chord
        var numVoicesParam:IParameter = getParam(ParameterNames.VOICES_NUMBER)[0];
        var numVoicesPercent:Number = ((settings.getValueAt(numVoicesParam, percentTime) as uint) * 0.01) as Number;
        var maxNumVoices:int = _getTotalNumVoices(instruments);
        var numVoices:int = (maxNumVoices >= 2) ? Math.max(CoreOperationKeys.MIN_NUM_VOICES,
                Math.ceil(numVoicesPercent * maxNumVoices)) : 1;

        // Build pitches table (must be rebuilt because the `high` and `low` limits might have changed)
        var allPitches:Array = new Array(highest - lowest + 1);
        for (var midiPitch:int = lowest, counter:int = 0; midiPitch <= highest; midiPitch++) {
            allPitches[counter++] = midiPitch;
        }

        // Build „range zones", based on the total number of available voices.
        // NOTE: it is important whether a voice will occupy half of a staff or the entire staff. Some instruments
        // combine both situations.
        // TODO: refactor based on the above observation.
        var rangeZones:Array = [];
        var zoneSize:uint = Math.ceil(allPitches.length / _totalNumVoices);
        while (allPitches.length > 0) {
            rangeZones.push(allPitches.splice(0, zoneSize));
        }

        // Adjust the range zones to fit inside the range of the corresponding instrument.
        var rangeZonesClone:Array = rangeZones.concat();
        for (var revIndex:int = instruments.length - 1; revIndex >= 0; revIndex--) {
            var instrument:IMusicalInstrument = instruments[revIndex];
            var instNumVoices:int = instrument.maximumAutonomousVoices;
            var instHighest:int = instrument.midiRange[1];
            var instLowest:int = instrument.midiRange[0];
            var instrumentZones:Array = rangeZonesClone.splice(0, instNumVoices);

            instrumentZones.forEach(function forEachZone(zone:Array, voiceIndex:int, ...etc):void {
                var spliceArgs:Array = zone.filter(function filterByMidiPitch(midiPitch:int, ...etc):Boolean {
                    return (midiPitch >= instLowest && midiPitch <= instHighest);
                });
                spliceArgs.unshift(zone.length);
                spliceArgs.unshift(0);
                zone.splice.apply(zone, spliceArgs);

                // N.B.: storing static properties on an Array of integers/MIDI pitches.
                // MAIDENS lays out voices from top to bottom; as our Array has the bass zone in first index, we
                // need to report voices in reverse order.
                zone.instrument = instrument;
                zone.voiceIndex = (instrumentZones.length - 1 - voiceIndex);
            });
        }

        // Based on the current number of voices that we must use, randomly employ one or more of
        // the range zones built above. For consistency, maintain the zones order and their total
        // number (use zero-element zones as placeholders).
        var zoneIndex:int;
        var zoneIndices:Array = [];
        for (zoneIndex = 0; zoneIndex < rangeZones.length; zoneIndex++) {
            zoneIndices.push(zoneIndex);
        }
        var zoneIndicesToUse:Array = Arrays.getSubsetOf(zoneIndices, Math.min(zoneIndices.length, numVoices));
        var zonesToUse:Array = [];
        for (zoneIndex = 0; zoneIndex < rangeZones.length; zoneIndex++) {
            if (zoneIndicesToUse.indexOf(zoneIndex) != -1) {
                zonesToUse[zoneIndex] = rangeZones[zoneIndex];
            } else {
                var placeHolder:Array = [];
                zonesToUse[zoneIndex] = placeHolder;

                // Recover zone instrument and voice index from original zone
                var skippedZone:Array = rangeZones[zoneIndex] as Array;
                placeHolder.instrument = skippedZone.instrument;
                placeHolder.voiceIndex = skippedZone.voiceIndex;
            }
        }

        // Pick a MIDI value from each eligible zone. Use the reserved MIDI pitch `0` for non eligible zones. When
        // rendering to score, all `0` MIDI pitches will be translated to rests.
        // We transfer chosen pitches to a MusicUnit (as this is the standardized vehicle we use to carry any type
        // of information).
        //
        // NOTE:
        // We previously have internally sorted instruments based on their relative pitch and score order rules, and
        // have assigned pitches to our chord/MusicUnit based on this sorted order. However, in the score,
        // instruments might be in any order. We now need to explicitly give pitch allocation rules, so that each
        // pitch eventually reaches its intended instrument.
        var tmpMusicUnit:IMusicUnit = new MusicUnit;
        var tmpPitches:Vector.<IMusicPitch> = tmpMusicUnit.pitches;
        var tmpAllocations:Vector.<IPitchAllocation> = tmpMusicUnit.pitchAllocations;
        zonesToUse.forEach(function forEachZoneToUse(zone:Array, ...etc):void {
            var pitch:IMusicPitch = new MusicPitch;
            if (zone.length > 0) {
                pitch.midiNote = _enforceConsonance?
                        CommonMusicUtils.findSuitablePitch(zone, tmpPitches, _currentConsonance):
                        (Arrays.getRandomItem(zone) as int);
            } else {
                pitch.midiNote = 0;
            }
            tmpPitches.push(pitch);
            var allocation:IPitchAllocation = new PitchAllocation(zone.instrument as IMusicalInstrument,
                    zone.voiceIndex as int, pitch);
            tmpAllocations.push(allocation);
        });

        return tmpMusicUnit;
    }

    /**
     * Determines if pitches contained by provided IMusicUnit implementor instance depict a "shallow"
     * chord, that is a chord transporting little harmonic information due to excessive doubling, such as,
     * e.g., C4-C5-C6.
     *
     * NOTES:
     * Starting with v.1.5.1, we will avoid outputting "chords" like "C3-C4-C5", or (when applicable) "C3-E3-C5",
     * as the harmonic analyzer gives these good scores (for their lack of dissonances), whereas they really
     * sound dull and "neutral" at best.
     *
     * The rule employed will be:
     * << Each chord must have at least NUM_VOICES-1 different simple intervals (e.g., "decomposed intervals",
     * or INT_NAME % 12) against the bass, not counting the perfect prime. >>
     *
     * That is to say that I want at least two pitches that are different than the chord's bass pitch, not
     * counting doubling, in all chords that use at least three "voices". EXAMPLES:
     * C4-E4-G4 has intervals C4-E4 and C4-G4 (against bass), which counts as "2", which is less by one than
     * "3", which is the voices number of the chord, so this chord would be acceptable; C4-E4-C5 has intervals
     * C4-E4 and C5-C5 (against bass), with later decomposing to C4-C4, that is, a prime, so it is ignored, so
     * this only counts one interval (the C4-E4), so it is less by two than "3", which is the voices number of
     * the chord, so this chord would NOT be acceptable.
     *
     * This function will generate chords until a suitable one is produced.
     *
     * @param   chord
     *          The chord to asses, in form of a IMusicUnit implementor instance (typically a MusicUnit).
     *
     * @return  True if the chord is shallow, false otherwise.
     */
    private function _isShallowChord(chord:IMusicUnit):Boolean {
        var pitches:Vector.<IMusicPitch> = chord.pitches;
        var numPitches:uint = pitches.filter(function filterPitchesToCount(pitch:IMusicPitch, ...etc):Boolean {
            return pitch != 0
        }).length;

        // If this "chord" is comprised of a lone pitch (which is possible if user sets the
        // "Number of voices" parameter to the minimum), then this function should not interfere, and it
        // should allow such a chord to "pass through", by declaring it valid (i.e., "not invalid").
        if (numPitches < 2) {
            return false;
        }

        // The chord is "shallow" (thus, "invalid") if its number of unique simple intervals observed against
        // the bass (not counting primes) is less than the minimum accepted number of unique intervals in a chord.
        var intervalsAgainstBass:Array = _getIntervalsAgainstBass(pitches, true, true);
        var minAcceptedNumIntervals:int = Math.min(numPitches - 1, REFERENCE_NUM_MIN_INTERVALS);
        var isChordShallow:Boolean = (intervalsAgainstBass.length < minAcceptedNumIntervals);
        return isChordShallow;
    }

    /**
     * Returns an Array with positive integers depicting all intervals forming by all upper pitches
     * against the lowest (i.e., bass) pitch. Optionally decomposes intervals, so that a major third
     * over one octave (16 semitones) will still read as a mere major third (4 semitones), and, also
     * optionally, omits perfect primes (0 semitones) entirely from the reported set.
     *
     * @param   pitches
     *          The set of pitches to extract intervals from as a Vector of IMusicPitch implementor
     *          instances.
     *
     * @param   decomposeIntervals
     *          Whether to decompose intervals.
     *
     * @param   omitPrimes
     *          Whether to omit perfect primes.
     *
     * @return  An Array with all observed intervals.
     */
    private function _getIntervalsAgainstBass(pitches:Vector.<IMusicPitch>, decomposeIntervals:Boolean,
                                              omitPrimes:Boolean):Array {
        var i:int;
        var rawMidiValues:Array = [];
        var intervals:Array = [];
        for (i = 0; i < pitches.length; i++) {
            rawMidiValues[i] = pitches[i].midiNote;
        }
        rawMidiValues.sort();
        var bassNote:int = (rawMidiValues.shift() as int);
        var currNote:int;
        var interval:int;
        for (i = 0; i < rawMidiValues.length; i++) {
            currNote = (rawMidiValues[i] as int);
            interval = Math.abs(bassNote - currNote);
            if (decomposeIntervals) {
                interval = (interval % IntervalsSize.PERFECT_OCTAVE);
            }
            if (omitPrimes && (interval == 0)) {
                continue;
            }
            if (intervals.indexOf(interval) == -1) {
                intervals.push(interval);
            }
        }
        return intervals;
    }

    private function _compareRangeZones(zoneA:Array, zoneB:Array):int {
        return (zoneA[0] - zoneB[0]);
    }

    /**
     * Returns the total number of polyphonic voices the instruments currently in use can provide.
     * Results are cached.
     */
    private function _getTotalNumVoices(instruments:Vector.<IMusicalInstrument>):int {
        if (!_totalNumVoices) {
            for (var i:int = 0; i < instruments.length; i++) {
                var instrument:IMusicalInstrument = instruments[i];
                _totalNumVoices += instrument.maximumAutonomousVoices;
            }
        }
        return _totalNumVoices;
    }

    /**
     * Returns the average "middle range" of the instruments currently in use. The source of this
     * information is the `idealHarmonicRange` setting of each instrument, which is usually somewhere
     * in the middle toward high instrument's range.
     */
    private function _getAverageMiddleRange(instruments:Vector.<IMusicalInstrument>):Vector.<int> {
        if (!_averageMiddleRange) {
            var lowLimitSum:int = 0;
            var highLimitSum:int = 0;
            var i:int;
            var instrument:IMusicalInstrument;
            for (i = 0; i < instruments.length; i++) {
                instrument = instruments[i];
                lowLimitSum += instrument.idealHarmonicRange[0];
                highLimitSum += instrument.idealHarmonicRange[1];
            }
            var lowLimitAverage:int = Math.ceil(lowLimitSum / instruments.length);
            var highLimitAverage:int = Math.floor(highLimitSum / instruments.length);
            _averageMiddleRange = Vector.<int>([lowLimitAverage, highLimitAverage]);
        }
        return _averageMiddleRange;
    }

    /**
     * Returns the highest pitch any of the instruments currently in use is able to produce.
     */
    private function _getHighestAvailablePitch(instruments:Vector.<IMusicalInstrument>):int {
        if (!_highestAvailablePitch) {
            var i:int;
            var instrument:IMusicalInstrument;
            var localHighest:int;
            var globalHighestPitch:int = 0;
            for (i = 0; i < instruments.length; i++) {
                instrument = instruments[i];
                localHighest = instrument.midiRange[1];
                if (localHighest > globalHighestPitch) {
                    globalHighestPitch = localHighest;
                }
            }
            _highestAvailablePitch = globalHighestPitch;
        }
        return _highestAvailablePitch;
    }

    /**
     * Returns the lowest pitch any of the instruments currently in use is able to produce.
     */
    private function _getLowestAvailablePitch(instruments:Vector.<IMusicalInstrument>):int {
        if (!_lowestAvailablePitch) {
            var i:int;
            var instrument:IMusicalInstrument;
            var localLowest:int;
            var globalLowestPitch:int = int.MAX_VALUE;
            for (i = 0; i < instruments.length; i++) {
                instrument = instruments[i];
                localLowest = instrument.midiRange[0];
                if (localLowest < globalLowestPitch) {
                    globalLowestPitch = localLowest;
                }
            }
            _lowestAvailablePitch = globalLowestPitch;
        }
        return _lowestAvailablePitch;
    }
}
}
