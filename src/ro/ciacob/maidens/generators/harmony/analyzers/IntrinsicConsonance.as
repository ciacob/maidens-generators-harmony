package ro.ciacob.maidens.generators.harmony.analyzers {
	
	import ro.ciacob.maidens.generators.constants.pitch.IntervalsSize;
	import ro.ciacob.maidens.generators.core.abstracts.AbstractContentAnalyzer;
	import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicPitch;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalContentAnalyzer;
	import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
	import ro.ciacob.maidens.generators.harmony.constants.ParameterNames;
	
	/**
	 * Establishes the harmonic consonance of an isolated chord, based on the consonance of its
	 * constituent intervals.
	 */
	public class IntrinsicConsonance extends AbstractContentAnalyzer implements IMusicalContentAnalyzer {
		
		// [DEBUG]
		// public static const DEBUG : Array = [];
		// [/DEBUG]
		
		private const MIN_LEGAL_SCORE : int = 1;
		
		private static const MAX_CONSONANCE : Number = 1300;
		private static const DIMINISHED_CHORD_PENALTY_FACTOR : Number = 0.85;
		private static const AUGMENTED_CHORD_PENALTY_FACTOR : Number = 0.8;
		private static const QUARTAL_CHORD_PENALTY_FACTOR : Number = 0.75;
		private static const SINGLE_TRITONE_PENALTY_OFFSET : Number = -400;
		private static const MULTIPLE_TRITONES_PENALTY_OFFSET : Number = -200;
		private static const MINOR_SECOND_PENALTY_OFFSET : Number = -300;
		private static const MAJOR_SEVENTH_PENALTY_OFFSET : Number = -150;
		private static const MAJOR_SECOND_PENALTY_OFFSET : Number = -200;
		private static const MINOR_SEVENTH_PENALTY_OFFSET : Number = -50;

		private var _allIntervalsCache : Array;
		private var _adjacentIntervalsCache : Array;
		private var _compoundIntervals: Array;
		private var _simpleIntervals: Array;
		private var _adjacentIntervals : Array;
		private var _pitches : Vector.<IMusicPitch>;
		private var _numPitches : int;
		
		/**
		 * @constructor
		 */
		public function IntrinsicConsonance () {
			super (this);
		}

		/**
		 * @see IMusicalContentAnalyzer.weight
		 */
		override public function get weight () : Number {
			return 0.99;
		}

		/**
		 * @see IMusicalContentAnalyzer.name
		 */
		override public function get name () : String {
			return ParameterNames.INTRINSIC_CONSONANCE;
		}
		
		/**
		 * Analyzes the intrinsic consonance of a given IMusicUnit instance. Produces a score expressed as
		 * a rational number between `1` (fully consonant) and `0` (fully dissonant).
		 * @see IMusicalContentAnalyzer.analyze
		 */
		override public function analyze (targetMusicUnit : IMusicUnit, analysisContext : IAnalysisContext,
										  parameters : IParametersList, request : IMusicRequest) : void {
			
			// Collect and sort all intervals found in the current chord (IMusicUnit instance)
			_allIntervalsCache = [];
			_compoundIntervals = [];
			_simpleIntervals = [];
			_adjacentIntervals = [];
			_pitches = targetMusicUnit.pitches;
			_numPitches = _pitches.length; 
			for (var i : int = 0; i < _numPitches; i++) {
				var currentPitch : IMusicPitch = _pitches[i];
				var remainderPitches : Vector.<IMusicPitch> = _pitches.slice(i + 1);
				var numRemainderPitches : int = remainderPitches.length;
				for (var j:int = 0; j < numRemainderPitches; j++) {
					var otherPitch : IMusicPitch = remainderPitches[j];
					var interval : int = Math.abs (currentPitch.midiNote - otherPitch.midiNote);
					_compoundIntervals.push (interval);
					var simpleInterval : int = interval % IntervalsSize.PERFECT_OCTAVE;
					_simpleIntervals.push (simpleInterval);
					if (j == 0) {
						_adjacentIntervals.push (simpleInterval);
					}
				}
			}

			// Compute and store the consonance score
			var score : Number = (_computeScore (_simpleIntervals) / MAX_CONSONANCE);
			score *= weight;
			score = Math.max (MIN_LEGAL_SCORE, Math.round (score * 100));
			targetMusicUnit.analysisScores.add (ParameterNames.INTRINSIC_CONSONANCE, score);
		}
		
		/**
		 * Computes and returns a (raw) consonnace score based on Paul Hindemith's observations from 
		 * "Introduction in composition" (1953).
		 */
		private function _computeScore(intervals : Array) : Number {
			
			// Diminished, augmented and quartal chords have, each, established scores
			if (_isDiminishedChord ()) {
				return (MAX_CONSONANCE * DIMINISHED_CHORD_PENALTY_FACTOR);			
			}
			if (_isAugmentedChord ()) {
				return (MAX_CONSONANCE * AUGMENTED_CHORD_PENALTY_FACTOR);
			}
			if (_isQuartalChord ()) {
				return (MAX_CONSONANCE * QUARTAL_CHORD_PENALTY_FACTOR);
			}
			
			// For the rest of the chords the score is computed by applying specific penalties
			// based on the various classes of dissonances the chord contains
			var score : Number = MAX_CONSONANCE;
			if (_hasTritone (intervals)) {
				score += SINGLE_TRITONE_PENALTY_OFFSET;
			}
			if (_hasTritones (intervals)) {
				score += MULTIPLE_TRITONES_PENALTY_OFFSET;
			}
			if (_hasAnyMinorSecond (intervals)) {
				score += MINOR_SECOND_PENALTY_OFFSET;
			}
			if (_hasAnyMajorSeventh (intervals)) {
				score += MAJOR_SEVENTH_PENALTY_OFFSET;
			}
			if (_hasAnyMajorSecond (intervals)) {
				score += MAJOR_SECOND_PENALTY_OFFSET;
			}
			if (_hasAnyMinorSeventh (intervals)) {
				score += MINOR_SEVENTH_PENALTY_OFFSET;
			}
			return score;
		}
		
		/**
		 * Returns `true` if given intervals set contains at least two tritones.
		 */
		private function _hasTritones (intervals : Array) : Boolean {
			var answer : Boolean = (_countIntOccurences (IntervalsSize.AUGMENTED_FOURTH, intervals, _allIntervalsCache) >= 2);
			return answer;
		}
		
		/**
		 * Returns `true` if given intervals set contains a tritone.
		 */
		private function _hasTritone (intervals : Array) : Boolean {
			var answer : Boolean = (_countIntOccurences (IntervalsSize.AUGMENTED_FOURTH, intervals, _allIntervalsCache) == 1);
			return answer;
		}
		
		/**
		 * Returns `true` if given intervals set contains a minor second.
		 */
		private function _hasAnyMinorSecond (intervals : Array) : Boolean {
			var answer : Boolean = (_countIntOccurences (IntervalsSize.MINOR_SECOND, intervals, _allIntervalsCache) > 0);
			return answer;
		}
		
		/**
		 * Returns `true` if given intervals set contains a major second.
		 */
		private function _hasAnyMajorSecond(intervals : Array) : Boolean {
			var answer : Boolean = (_countIntOccurences (IntervalsSize.MAJOR_SECOND, intervals, _allIntervalsCache) > 0);
			return answer;
		}
		
		/**
		 * Returns `true` if given intervals set contains a major seventh.
		 */
		private function _hasAnyMajorSeventh (intervals : Array) : Boolean {
			var answer : Boolean = (_countIntOccurences (IntervalsSize.MAJOR_SEVENTH, intervals, _allIntervalsCache) > 0);
			return answer;
		}

		/**
		 * Returns `true` if given intervals set contains a minor seventh.
		 */
		private function _hasAnyMinorSeventh (intervals : Array) : Boolean {
			var answer : Boolean = (_countIntOccurences (IntervalsSize.MINOR_SEVENTH, intervals, _allIntervalsCache) > 0);
			return answer;
		}
		
		/**
		 * Returns `true` if given `intervals` describe a diminished chord structure.
		 * Reducing all compond intervals, a diminished chord will only contain 3m, or
		 * only contain 3m and 4+, or only contain 3m, 4+ and 6M
		 */
		private function _isDiminishedChord () : Boolean {
			var numAdjacentIntervals : int = _adjacentIntervals.length;
			var numMinorThirds : int = _countIntOccurences (IntervalsSize.MINOR_THIRD, _adjacentIntervals, _adjacentIntervalsCache);
			var numTritones : int = _countIntOccurences (IntervalsSize.AUGMENTED_FOURTH, _adjacentIntervals, _adjacentIntervalsCache);
			var numMajorSixths : int = _countIntOccurences (IntervalsSize.MAJOR_SIXTH, _adjacentIntervals, _adjacentIntervalsCache);
			var answer : Boolean = (numMinorThirds == numAdjacentIntervals) || (numMinorThirds + numTritones == numAdjacentIntervals) || 
				(numMinorThirds + numTritones + numMajorSixths == numAdjacentIntervals);
			return answer;
		}
		
		/**
		 * Returns `true` if given `intervals` describe an augmented chord structure.
		 * Reducing all compond intervals, an augmented chord only contains 3M, or only contains 6m.
		 */
		private function _isAugmentedChord () : Boolean {
			var numAdjacentIntervals : int = _adjacentIntervals.length;
			var numMajorThirds : int = _countIntOccurences (IntervalsSize.MAJOR_THIRD, _adjacentIntervals, _adjacentIntervalsCache);
			var numMinorSixths : int = _countIntOccurences (IntervalsSize.MINOR_SIXTH, _adjacentIntervals, _adjacentIntervalsCache);
			var answer : Boolean = (numMajorThirds == numAdjacentIntervals) || (numMinorSixths == numAdjacentIntervals);
			return answer;
		}

		/**
		 * Returns `true` if given `intervals` describe a cvartal chord structure.
		 * Reducing all compond intervals, a cvartal chord only contains 4p. NOTE THAT WE
		 * DO NOT ADDRESS CVARTAL INVERSIONS here, as they match other, more specific
		 * rules instead.
		 */
		private function _isQuartalChord () : Boolean {
			var numAdjacentIntervals : int = _adjacentIntervals.length;
			var numFourths : int = _countIntOccurences (IntervalsSize.PERFECT_FOURTH, _adjacentIntervals, _adjacentIntervalsCache);
			var answer : Boolean = (numFourths == numAdjacentIntervals);
			return answer;
		}

		
		/**
		 * Counts and returns the number of occurences of a given integer value within a given set.
		 * 
		 * @param	$int
		 * 			The numeric (integer) value to look for.
		 * 
		 * @param	$arr
		 * 			The set (Array) to look into.
		 * 
		 * @param	$cache
		 * 			Optional. An Array to store counted occurences in, so that recounting them on each
		 * 			function invocation is not needed. 
		 */
		private function _countIntOccurences ($int : int, $arr : Array, $cache : Array = null) : int {
			var counter : Array = $cache || [];
			if (counter.length == 0) {
				for (var i:int = 0; i < $arr.length; i++) {
					var interval : int = $arr[i];
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