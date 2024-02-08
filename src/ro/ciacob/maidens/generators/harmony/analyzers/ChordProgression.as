package ro.ciacob.maidens.generators.harmony.analyzers {
import ro.ciacob.maidens.generators.constants.BiasTables;
import ro.ciacob.maidens.generators.constants.pitch.IntervalsSize;
import ro.ciacob.maidens.generators.core.abstracts.AbstractContentAnalyzer;
import ro.ciacob.maidens.generators.core.helpers.CommonMusicUtils;
import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
import ro.ciacob.maidens.generators.core.interfaces.IMusicPitch;
import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
import ro.ciacob.maidens.generators.core.interfaces.IMusicalContentAnalyzer;
import ro.ciacob.maidens.generators.core.interfaces.IParameter;
import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
import ro.ciacob.maidens.generators.core.interfaces.ISettingsList;
import ro.ciacob.maidens.generators.harmony.constants.ParameterCommons;
import ro.ciacob.maidens.generators.harmony.constants.ParameterNames;
import ro.ciacob.utils.Arrays;

/**
 * Audits the overall voice-leading profile of two chords observed in isolation from the harmonic context they evolve in.
 */
public class ChordProgression extends AbstractContentAnalyzer implements IMusicalContentAnalyzer {
    private var _maxPossibleScore:int;
    private var _minPossibleScore:int;
    private var _externalMelodicScores:Array;
    private var _internalMelodicScores:Array;

    /**
     * @constructor
     */
    public function ChordProgression() {
        super(this);
    }

    /**
     * @see IMusicalContentAnalyzer.name
     */
    override public function get name():String {
        return ParameterNames.CHORD_PROGRESSION;
    }

    /**
     * @see IMusicalContentAnalyzer.weight
     */
    override public function get weight():Number {
        return 0.7;
    }

    /**
     * Analyses melodic movement of each corresponding pair of pitches from two neighbour
     * MusicUnits, and yield score that favor "classical" chord progression, where
     * "external voices" move more than "internal voices".
     * @see IMusicalContentAnalyzer.analyze
     * [CHECKED]
     */
    override public function analyze(
            targetMusicUnit:IMusicUnit,
            analysisContext:IAnalysisContext,
            parameters:IParametersList,
            request:IMusicRequest):void {

        _externalMelodicScores = BiasTables.EXTERNAL_VOICES_MELODIC_BIAS.concat();
        _internalMelodicScores = BiasTables.INTERNAL_VOICES_MELODIC_BIAS.concat();

        // Adjust the likeliness of holding onto the same pitch while moving to the
        // next Music Unit. This directly influences the likeliness of held notes on a
        // "per-voice" basis, and causes a blend of polyphony to mix into the, otherwise,
        // homophonic choral.
        var percentTime:int = Math.round(analysisContext.percentTime * 100);
        var settings:ISettingsList = request.userSettings;
        var restlessnessParam:IParameter = parameters.getByName(ParameterNames.VOICE_RESTLESSNESS)[0];
        var restlessNess:uint = (settings.getValueAt(restlessnessParam, percentTime) as uint);
        var rawSteadinessFactor:Number = (((99 - (restlessNess - 1)) / 99) as Number);
        var minSteadinessFactor:Number = ParameterCommons.VOICE_RESTLESSNESS_MIN;
        var maxSteadinessFactor:Number = ParameterCommons.VOICE_RESTLESSNESS_MAX;
        var steadinessFactor:Number = (((maxSteadinessFactor - minSteadinessFactor) * rawSteadinessFactor) + minSteadinessFactor);
        _externalMelodicScores[IntervalsSize.PERFECT_UNISON] *= steadinessFactor;
        _internalMelodicScores[IntervalsSize.PERFECT_UNISON] *= steadinessFactor;
        _normalizeTable(_externalMelodicScores);
        _normalizeTable(_internalMelodicScores);

        // Extract the reference (previous) chord
        var prevContent:Vector.<IMusicUnit> = analysisContext.previousContent;


        // If this is the first chord, it is equally good or bad, since there has never
        // been any voice leading. Therefore, store a score of `NA_RESERVED_VALUE` for it.
        if (prevContent.length == 0) {
            targetMusicUnit.analysisScores.add(ParameterNames.CHORD_PROGRESSION,
                    ParameterCommons.NA_RESERVED_VALUE);
            return;
        }

        var prevUnit:IMusicUnit = prevContent[prevContent.length - 1];
		var prevUnitPitches : Vector.<IMusicPitch> = CommonMusicUtils.getRealPitches (prevUnit.pitches);
		var prevNumPitches : uint = prevUnitPitches.length;

		// If the previous "chord" consists entirely of rests, things are rather debatable, strictly musically speaking.
		// For the time being, we choose to store a score of `NA_RESERVED_VALUE` as well, essentially meaning that
		// anything could follow a rest, from a voice-leading perspective.
		if (prevNumPitches == 0) {
			targetMusicUnit.analysisScores.add(ParameterNames.CHORD_PROGRESSION,
					ParameterCommons.NA_RESERVED_VALUE);
			return;
		}

		var currPitches : Vector.<IMusicPitch> = CommonMusicUtils.getRealPitches (targetMusicUnit.pitches);
		var currNumPitches:uint = currPitches.length;

		// If the current "chord" consists entirely of rests, the same considerations and resolution shall apply.
		if (currNumPitches == 0) {
			targetMusicUnit.analysisScores.add(ParameterNames.CHORD_PROGRESSION,
					ParameterCommons.NA_RESERVED_VALUE);
			return;
		}

		// If neither previous nor current chord have at least two voices, we will exit as well. We will want this
		// situation to be controlled by melodic rather than harmonic analyzers. It is acceptable, though, that one of
		// the two only have one voice.
		if (prevNumPitches < 2 && currNumPitches < 2) {
			targetMusicUnit.analysisScores.add(ParameterNames.CHORD_PROGRESSION,
					ParameterCommons.NA_RESERVED_VALUE);
			return;
		}

        // Store the maximum and minimum scores that can be achieved; this will help
        // us produce a normalized result (a rational number between `0` and `1`). We
        // cache these values for as long as the number of pitches/chord notes stays
        // the same.
        _computeScoreLimits(currNumPitches);

		// Clean up both operands (remove rests from both previous and current chord), in order to reduce the odds of
		// misleading the analyzer. This is volatile, i.e., the actual music units are not modified.

		var cleanPrevUnit : IMusicUnit = prevUnit;
		var cleanCurrUnit : IMusicUnit = targetMusicUnit;

		// TODO: uncomment after the ChordProgression analyzer is reviewed/rewritten.
		// var cleanPrevUnit : IMusicUnit = CommonMusicUtils.substitutePitchesOf(prevUnit, prevUnitPitches);
		// var cleanCurrUnit : IMusicUnit = CommonMusicUtils.substitutePitchesOf(targetMusicUnit, currPitches);
		// trace ('inside ChordProgression; _computeProgressionScore is actually run with:', cleanPrevUnit, cleanCurrUnit);

        // Compute and store the chord progression score.
        var rawScore:int = _computeProgressionScore(cleanPrevUnit, cleanCurrUnit);
        var rawDelta:int = (rawScore - _minPossibleScore);
        var refDelta:int = (_maxPossibleScore - _minPossibleScore);
        var score:Number = (rawDelta / refDelta);
        score = Math.max(ParameterCommons.MIN_LEGAL_SCORE, Math.round(score * 100));
        targetMusicUnit.analysisScores.add(ParameterNames.CHORD_PROGRESSION, score);
    }

    /**
     * Normalizes in-place the given Array of Numbers, making sure that they sum up
     * to 100, while keeping their original proportions.
     * [CHECKED]
     */
    private function _normalizeTable(table:Array):void {
        var tableSum:Number = 0;
        var checkSum:Number = 0;
        table.forEach(function (entryValue:Number, entryIndex:uint, srcTable:Array):void {
            entryValue = Math.round(entryValue * 1000);
            srcTable[entryIndex] = entryValue;
            tableSum += entryValue;
        });
        table.forEach(function (entryValue:Number, entryIndex:uint, srcTable:Array):void {
            var entryPercent:Number = (entryValue / tableSum);
            entryValue = Math.round(entryPercent * 100);
            srcTable[entryIndex] = entryValue;
            checkSum += entryValue;
        });

        // If, after normalization, the values inside the table do not precisely
        // add up to 100 (which can happen due to rounding errors), the offset is
        // added to the first element of the table.
        var checkDelta:int = (100 - checkSum);
        table[0] += checkDelta;
    }

    /**
     * Calculates the maximum and minimum possible scores for the given number of
     * pitches/voices.
     * [CHECKED]
     */
    private function _computeScoreLimits(numPitches:uint):void {

        // Find the maximum possible bias for external voices
        var extVoiceBiases:Array = _externalMelodicScores.concat();
        extVoiceBiases.sort(Array.NUMERIC | Array.DESCENDING);
        var maxExtVoiceBias:Number = extVoiceBiases.shift() as Number;
        var minExtVoiceBias:Number = extVoiceBiases.pop() as Number;

        // Find the maximum possible bias for internal voices
        var intVoicesBias:Array = _internalMelodicScores.concat();
        intVoicesBias.sort(Array.NUMERIC | Array.DESCENDING);
        var maxIntVoiceBias:Number = intVoicesBias.shift() as Number;
        var minIntVoiceBias:Number = intVoicesBias.pop() as Number;

        // Use the maximum bias for "external voices" twice (as there are two "external
        // voices", the "soprano" and the "bass"), and the maximum bias for "internal
        // voices" for each remaining voice (as they will all be "internal voices").
        // Decrease the bias factor as we progress through the voices (because "internal
        // voices" are, melodically, less important than "external voices": in fact, the
        // more "internal" a voice is, the less melodically important it is).
        const NUM_EXTERNAL_VOICES:int = 2;
        _maxPossibleScore = 1;
        _minPossibleScore = 1;
        var biasFactor:int = numPitches;
        var voiceCounter:int = 0;
        while (biasFactor > 0) {
            _maxPossibleScore += ((voiceCounter < NUM_EXTERNAL_VOICES) ? maxExtVoiceBias : maxIntVoiceBias) * biasFactor;
            _minPossibleScore += ((voiceCounter < NUM_EXTERNAL_VOICES) ? minExtVoiceBias : minIntVoiceBias) * biasFactor;
            biasFactor--;
            voiceCounter++;
        }
    }

    /**
     * Computes the "chord progression score", which is a mean of describing how much the
     * voice leading in two neighbour chords loosely conforms to rules of classic
     * four-part writing.
     *
     * This is a mere approximation, done by observing the melodic relationship each
     * note from the first chord makes with its counterpart from the second chord. The
     * goal is to favor those chord succession where "internal voices" move in step
     * motion (or small skips). "External voices" are encouraged to mix in more skips, in
     * order to increase the odds for a more expressive "soprano" or "bass".
     * [CHECKED]
     */
    private function _computeProgressionScore(unitA:IMusicUnit, unitB:IMusicUnit):uint {

        // Extract the pitches, so that we can work non-destructively.
        var i:int;
        var pitchesA:Array = [];
        var pitches:Vector.<IMusicPitch> = unitA.pitches;
        var midiNote:uint;
        for (i = 0; i < pitches.length; i++) {
            midiNote = pitches[i].midiNote;
            if (midiNote > 0) {
                pitchesA.push(midiNote);
            }
        }
        var pitchesB:Array = [];
        pitches = unitB.pitches;
        for (i = 0; i < pitches.length; i++) {
            midiNote = pitches[i].midiNote;
            if (midiNote > 0) {
                pitchesB.push(midiNote);
            }
        }

        // We can only compute melodic progression for chords having the same number of
        // pitches (because every pitch in chord A must "lead" to a pitch in chord B).
        // If this is not the case, we duplicate the lesser chord until it has
        // the same number of pitches as the greater chord, or more. If needed, we trim
        // down the duplicated chord, top to bottom.
        var iNumPitchesA:uint = pitchesA.length;
        var iNumPitchesB:uint = pitchesB.length;
        if (iNumPitchesA != iNumPitchesB) {
            var bothChords:Array = [pitchesA, pitchesB];
            var bothChordsCopy:Array = bothChords.concat();
            bothChordsCopy.sort(function (arrA:Array, arrB:Array):int {
                return (arrA.length - arrB.length);
            });
            var lesserChord:Array = bothChordsCopy[0];
            var greaterChord:Array = bothChordsCopy[1];
            while (lesserChord.length < greaterChord.length) {
                var spliceArgs:Array = lesserChord.concat();
                spliceArgs.unshift(0, 0);
                lesserChord.splice.apply(lesserChord, spliceArgs);
            }
            lesserChord.sort(Array.NUMERIC);
            while (lesserChord.length > greaterChord.length) {
                Arrays.removeOneDupplicate(lesserChord, true);
            }
        }

        // In homophonic music, pitches in a chord (improperly named "voices") are
        // hierarchically organized in "external voices" (e.g., the bass and the
        // soprano in a SATB choir) and "internal voices" (e.g., the alto and the
        // tenor). External voices are, melodically, more important than internal
        // voices. Also, lower-pitched voices are melodically less important than
        // higher-pitched voices.
        //
        // Therefore, given two chords with `n` "voices" each, where `0` is the lowest
        // voice and `n` is the highest voice, we traverse both of them in
        // `n`, `0`, `n - 1`, `0 + 1`, etc. order, and, while doing so, we multiply
        // the corresponding voice leading score by a decreasing factor.
        //
        // The voice leading scores are stored in pre-calculated tables (see class
        // `BiasTables` for an explanation).
        var pitchA:uint;
        var pitchB:uint;
        var melodicInterval:uint;
        var biasTable:Array;
        var localBias:uint;
        var totalBias:uint = 0;
        var biasFactor:int = iNumPitchesA;

        // Start with chords in reversed image (highest pitches are in index 0 of both
        // Arrays).
        pitchesA.reverse();
        pitchesB.reverse();

        // "Peel" one pair of pitches at the time, working towards the inner voices,
        // starting with the "soprano".
        while (pitchesA.length > 0) {
            biasTable = ((pitchesA.length > (iNumPitchesA - 2)) ?
                    _externalMelodicScores : _internalMelodicScores);
            pitchA = pitchesA.shift();
            pitchB = pitchesB.shift();
            melodicInterval = Math.abs(pitchA - pitchB);
            localBias = ((biasTable[melodicInterval] as uint) * biasFactor)
            totalBias += localBias;
            pitchesA.reverse();
            pitchesB.reverse();
            biasFactor--;
        }
        return totalBias;
    }

}
}