package ro.ciacob.maidens.generators.harmony.analyzers {

import eu.claudius.iacob.music.knowledge.harmony.Intervals;

import ro.ciacob.maidens.generators.constants.pitch.IntervalsSize;
import ro.ciacob.maidens.generators.core.abstracts.AbstractContentAnalyzer;
import ro.ciacob.maidens.generators.core.helpers.CommonMusicUtils;
import ro.ciacob.maidens.generators.core.helpers.CommonMusicUtils;
import ro.ciacob.maidens.generators.core.helpers.IntervalRegistryEntry;
import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
import ro.ciacob.maidens.generators.core.interfaces.IMusicPitch;
import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
import ro.ciacob.maidens.generators.core.interfaces.IMusicalContentAnalyzer;
import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
import ro.ciacob.maidens.generators.harmony.constants.ParameterCommons;
import ro.ciacob.maidens.generators.harmony.constants.ParameterNames;

/**
 * Establishes the harmonic consonance of an isolated chord, based on the consonance of its
 * constituent intervals.
 */
public class IntrinsicConsonance extends AbstractContentAnalyzer implements IMusicalContentAnalyzer {

    private static const MIN_LEGAL_SCORE:int = 1;
    private var _allIntervalsRegistry:Vector.<IntervalRegistryEntry>;
    private var _allIntervalsCache:Array;
    private var _adjacentIntervalsCache:Array;
    private var _adjacentIntervals:Array;
    private var _lowestPitchInChord:int;

    /**
     * @constructor
     */
    public function IntrinsicConsonance() {
        super(this);
    }

    /**
     * @see IMusicalContentAnalyzer.weight
     */
    override public function get weight():Number {
        return 0.89;
    }

    /**
     * @see IMusicalContentAnalyzer.name
     */
    override public function get name():String {
        return ParameterNames.INTRINSIC_CONSONANCE;
    }

    /**
     * Analyzes the intrinsic consonance of a given IMusicUnit instance. Produces a score expressed as
     * a rational number between `1` (fully consonant) and `0` (fully dissonant).
     * @see IMusicalContentAnalyzer.analyze
     */
    override public function analyze(targetMusicUnit:IMusicUnit, analysisContext:IAnalysisContext,
                                     parameters:IParametersList, request:IMusicRequest):void {

        // Collect and sort all intervals found in the current chord (IMusicUnit instance)
        _allIntervalsRegistry = new Vector.<IntervalRegistryEntry>;
        _allIntervalsCache = [];
        var _simpleIntervals:Array = [];
        _adjacentIntervals = [];
        _lowestPitchInChord = int.MAX_VALUE;
        var _pitches:Vector.<IMusicPitch> = CommonMusicUtils.getRealPitches(targetMusicUnit.pitches);
        var _numPitches:int = _pitches.length;

        // Exit with illegal score if there are less than two playing voices (as it takes at least two voices to
        // "make harmony").
        if (_numPitches < 2) {
            targetMusicUnit.analysisScores.add(ParameterNames.INTRINSIC_CONSONANCE, ParameterCommons.NA_RESERVED_VALUE);
            return;
        }
        for (var i:int = 0; i < _numPitches; i++) {
            var currentPitch:IMusicPitch = _pitches[i];
            var currMidiNote:int = currentPitch.midiNote;
            if (currMidiNote < _lowestPitchInChord) {
                _lowestPitchInChord = currMidiNote;
            }
            var remainderPitches:Vector.<IMusicPitch> = _pitches.slice(i + 1);
            var numRemainderPitches:int = remainderPitches.length;
            for (var j:int = 0; j < numRemainderPitches; j++) {
                var otherPitch:IMusicPitch = remainderPitches[j];
                var interval:int = Math.abs(currMidiNote - otherPitch.midiNote);
                var simpleInterval:int = interval % IntervalsSize.PERFECT_OCTAVE;
                if (simpleInterval != 0) {
                    _simpleIntervals.push(simpleInterval);
                    _allIntervalsRegistry.push(new IntervalRegistryEntry(currMidiNote, simpleInterval));
                    if (j == 0) {
                        _adjacentIntervals.push(simpleInterval);
                    }
                }
            }
        }

        // Compute and store the consonance score
        var score:Number = (_computeScore(_simpleIntervals));
        score = Math.max(MIN_LEGAL_SCORE, score);
        targetMusicUnit.analysisScores.add(ParameterNames.INTRINSIC_CONSONANCE, score);
    }

    /**
     * Computes and returns a consonance score based on Paul Hindemith's observations from
     * "The craft of musical composition" (1953).
     */
    private function _computeScore(intervals:Array):Number {

        // Augmented and quartal chords in root position
        if (_isAugmentedChord() || _isQuartalChord()) {
            return CommonMusicUtils.AUGMENTED_OR_QUARTAL_SCORE;
        }

        // Diminished chords in any inversion, including diminished seventh chords
        if (_isDiminishedChord()) {
            return CommonMusicUtils.DIMINISHED_SCORE;
        }

        // Chords with no tritone
        var hasAnySeconds:Boolean;
        var hasAnySevenths:Boolean;
        if (!_hasAnyTritone(intervals)) {

            // Chords with no seconds, nor sevenths of any kind
            hasAnySeconds = (_hasAnyMinorSecond(intervals) || _hasAnyMajorSecond(intervals));
            hasAnySevenths = (_hasAnyMinorSeventh(intervals) || _hasAnyMajorSeventh(intervals));
            if (!hasAnySeconds && !hasAnySevenths) {
                if (_hasRootUpperInChord()) {
                    return CommonMusicUtils.TRIADS_WITH_ROOT_UPPER_SCORE;
                } else {
                    return CommonMusicUtils.TRIADS_WITH_ROOT_IN_BASS_SCORE;
                }
            }

            // Chords with some seconds, or some sevenths, or both (but no tritones)
            else {
                if (_hasRootUpperInChord()) {
                    return CommonMusicUtils.ADDED_NOTES_CHORDS_ROOT_UPPER_SCORE;
                } else {
                    return CommonMusicUtils.ADDED_NOTES_CHORDS_ROOT_IN_BASS_SCORE;
                }
            }
        }

        // Chords with at least one tritone
        else {

            // Chords that have a single tritone, no seconds, and a minor seventh (the typical
            // dominant chords in the tonality).
            hasAnySeconds = (_hasAnyMinorSecond(intervals) || _hasAnyMajorSecond(intervals));
            if (_hasSingleTritone(intervals) && !hasAnySeconds &&
                    !_hasAnyMajorSeventh(intervals) && _hasAnyMinorSeventh(intervals)) {
                return CommonMusicUtils.DOMINANT_TRIAD_SCORE;
            }

            // Chords that have a single tritone, no minor seconds, no major sevenths and either
            // major seconds, or minor sevenths, or both (typically the inversions of dominant
            // chords in the tonality).
            if (_hasSingleTritone(intervals) && !_hasAnyMinorSecond(intervals) &&
                    !_hasAnyMajorSeventh(intervals) &&
                    (_hasAnyMajorSecond(intervals) || _hasAnyMinorSeventh(intervals))) {
                if (_hasRootUpperInChord()) {
                    return CommonMusicUtils.DOMINANT_INVERSIONS_ROOT_UPPER_SCORE;
                } else {
                    return CommonMusicUtils.DOMINANT_INVERSIONS_ROOT_IN_BASS_SCORE;
                }
            }

            // Chords that have several tritones, no minor seconds, no major sevenths and either
            // major seconds, minor sevenths, or both (typically dominant ninths or over).
            if (_hasMultipleTritones(intervals) && !_hasAnyMinorSecond(intervals) &&
                    !_hasAnyMajorSeventh(intervals) &&
                    (_hasAnyMajorSecond(intervals) || _hasAnyMinorSeventh(intervals))) {
                return CommonMusicUtils.DOMINANT_NINTH_SCORE;
            }

            // Chords that have one or more tritones and either minor seconds, major sevenths, or
            // both (typically clusters).
            if (_hasAnyMinorSecond(intervals) || _hasAnyMajorSeventh(intervals)) {
                if (_hasRootUpperInChord()) {
                    return CommonMusicUtils.CLUSTERS_ROOT_UPPER_SCORE;
                } else {
                    return CommonMusicUtils.CLUSTERS_ROOT_IN_BASS_SCORE;
                }
            }
        }
        return MIN_LEGAL_SCORE;
    }

    /**
     * Returns `true` if given intervals set contains at least one tritone.
     */
    private function _hasAnyTritone(intervals:Array):Boolean {
        var answer:Boolean = (_countIntOccurrences(IntervalsSize.AUGMENTED_FOURTH, intervals, _allIntervalsCache) > 0);
        return answer;
    }

    /**
     * Returns `true` if given intervals set contains exactly one tritone.
     */
    private function _hasSingleTritone(intervals:Array):Boolean {
        var answer:Boolean = (_countIntOccurrences(IntervalsSize.AUGMENTED_FOURTH, intervals, _allIntervalsCache) == 1);
        return answer;
    }

    /**
     * Returns `true` if given intervals set contains at least two tritones.
     */
    private function _hasMultipleTritones(intervals:Array):Boolean {
        var answer:Boolean = (_countIntOccurrences(IntervalsSize.AUGMENTED_FOURTH, intervals, _allIntervalsCache) >= 2);
        return answer;
    }


    /**
     * Returns `true` if given intervals set contains a minor second.
     */
    private function _hasAnyMinorSecond(intervals:Array):Boolean {
        var answer:Boolean = (_countIntOccurrences(IntervalsSize.MINOR_SECOND, intervals, _allIntervalsCache) > 0);
        return answer;
    }

    /**
     * Returns `true` if given intervals set contains a major second.
     */
    private function _hasAnyMajorSecond(intervals:Array):Boolean {
        var answer:Boolean = (_countIntOccurrences(IntervalsSize.MAJOR_SECOND, intervals, _allIntervalsCache) > 0);
        return answer;
    }

    /**
     * Returns `true` if given intervals set contains a major seventh.
     */
    private function _hasAnyMajorSeventh(intervals:Array):Boolean {
        var answer:Boolean = (_countIntOccurrences(IntervalsSize.MAJOR_SEVENTH, intervals, _allIntervalsCache) > 0);
        return answer;
    }

    /**
     * Returns `true` if given intervals set contains a minor seventh.
     */
    private function _hasAnyMinorSeventh(intervals:Array):Boolean {
        var answer:Boolean = (_countIntOccurrences(IntervalsSize.MINOR_SEVENTH, intervals, _allIntervalsCache) > 0);
        return answer;
    }

    /**
     * Returns `true` if given intervals registry denotes a chord whose root (in Hindemith's
     * definition) is placed "upper in chord" (e.g., not in the bass).
     */
    private function _hasRootUpperInChord():Boolean {
        _allIntervalsRegistry.sort(Intervals.orderByHindemith2ndSeries);
        var mostSignificantInterval:IntervalRegistryEntry = _allIntervalsRegistry[0];
        return (mostSignificantInterval.root != _lowestPitchInChord);
    }

    /**
     * Returns `true` if collected `intervals` describe a diminished chord structure.
     * Reducing all compound intervals, a diminished chord will only contain 3m, or
     * only contain 3m and 4+, or only contain 3m, 4+ and 6M
     */
    private function _isDiminishedChord():Boolean {
        var numAdjacentIntervals:int = _adjacentIntervals.length;
        var numMinorThirds:int = _countIntOccurrences(IntervalsSize.MINOR_THIRD, _adjacentIntervals, _adjacentIntervalsCache);
        var numTritones:int = _countIntOccurrences(IntervalsSize.AUGMENTED_FOURTH, _adjacentIntervals, _adjacentIntervalsCache);
        var numMajorSixths:int = _countIntOccurrences(IntervalsSize.MAJOR_SIXTH, _adjacentIntervals, _adjacentIntervalsCache);
        var answer:Boolean = (numMinorThirds == numAdjacentIntervals) || (numMinorThirds + numTritones == numAdjacentIntervals) ||
                (numMinorThirds + numTritones + numMajorSixths == numAdjacentIntervals);
        return answer;
    }

    /**
     * Returns `true` if collected `intervals` describe an augmented chord structure.
     * Reducing all compound intervals, an augmented chord only contains 3M, or only contains 6m.
     */
    private function _isAugmentedChord():Boolean {
        var numAdjacentIntervals:int = _adjacentIntervals.length;
        var numMajorThirds:int = _countIntOccurrences(IntervalsSize.MAJOR_THIRD, _adjacentIntervals, _adjacentIntervalsCache);
        var numMinorSixths:int = _countIntOccurrences(IntervalsSize.MINOR_SIXTH, _adjacentIntervals, _adjacentIntervalsCache);
        var answer:Boolean = (numMajorThirds == numAdjacentIntervals) || (numMinorSixths == numAdjacentIntervals);
        return answer;
    }

    /**
     * Returns `true` if collected `intervals` describe a quartal chord structure.
     * Reducing all compound intervals, a quartal chord only contains 4p. NOTE THAT WE
     * DO NOT ADDRESS QUARTAL CHORDS INVERSIONS here, as they match other, more specific
     * rules instead.
     */
    private function _isQuartalChord():Boolean {
        var numAdjacentIntervals:int = _adjacentIntervals.length;
        var numFourths:int = _countIntOccurrences(IntervalsSize.PERFECT_FOURTH, _adjacentIntervals, _adjacentIntervalsCache);
        var answer:Boolean = (numFourths == numAdjacentIntervals);
        return answer;
    }

    /**
     * Counts and returns the number of occurrences of a given integer value within a given set.
     *
     * @param    $int
     *            The numeric (integer) value to look for.
     *
     * @param    $arr
     *            The set (Array) to look into.
     *
     * @param    $cache
     *            Optional. An Array to store counted occurrences in, so that recounting them on each
     *            function invocation is not needed.
     */
    private static function _countIntOccurrences($int:int, $arr:Array, $cache:Array = null):int {
        var counter:Array = $cache || [];
        if (counter.length == 0) {
            for (var i:int = 0; i < $arr.length; i++) {
                var interval:int = $arr[i];
                if (counter[interval] === undefined) {
                    counter[interval] = 0;
                }
                counter[interval]++;
            }
        }
        return counter[$int] || 0;
    }
}
}