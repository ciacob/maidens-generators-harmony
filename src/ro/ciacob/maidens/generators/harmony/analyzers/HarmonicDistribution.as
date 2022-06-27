package ro.ciacob.maidens.generators.harmony.analyzers {

	import ro.ciacob.maidens.generators.core.abstracts.AbstractContentAnalyzer;
	import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicPitch;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalContentAnalyzer;
	import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
	import ro.ciacob.maidens.generators.harmony.constants.ParameterCommons;
	import ro.ciacob.maidens.generators.harmony.constants.ParameterNames;
import ro.ciacob.utils.NumberUtil;

/**
	 * Audits the distribution of pitches in a chord, i.e., whether they tend to distribute in a
	 * pyramidal shape, or reversed pyramidal shape, or evenly.
	 */
	public class HarmonicDistribution extends AbstractContentAnalyzer implements IMusicalContentAnalyzer {

		/**
		 * @constructor
		 */
		public function HarmonicDistribution() {
			super(this);
		}

		/**
		 * @see IMusicalContentAnalyzer.name
		 */
		override public function get name () : String {
			return ParameterNames.HARMONIC_DISTRIBUTION;
		}

		/**
		 * @see IMusicalContentAnalyzer.weight
		 */
		override public function get weight () : Number {
			return 0.65;
		}

		/**
		 * @see IMusicalContentAnalyzer.analyze
		 */
		override public function analyze(
				targetMusicUnit:IMusicUnit,
				analysisContext:IAnalysisContext,
				parameters:IParametersList,
				request:IMusicRequest):void {

			// Get chord information
			var chordInfo:Object = _inspectChord(targetMusicUnit.pitches);

			// At least three pitches are needed to compute harmonic distribution
			if (chordInfo.numVoices < 3) {
				targetMusicUnit.analysisScores.add(ParameterNames.HARMONIC_DISTRIBUTION,
						ParameterCommons.NA_RESERVED_VALUE);
				return;
			}

			// Infers the maximum and minimum scores the current chord could achieve in best/worst case scenarios
			// then consolidates them into a positive integer, the "score gamut". This value heavily depends on
			// the smallest interval the chord has.
			var gamut:Number = _computeGamut(chordInfo);

			// Computes a raw score (such as `4`) by iteratively subtracting adjacent deltas, working from the
			// bass upward, and adding the values of the last surviving deltas pair.
			var rawScore:Number = _computeRawScore(chordInfo.chordIntervals);

			// Expresses the score as a percent, in relation to already computed gamut
			var score : Number = _transposeScore (rawScore, gamut);
			score = Math.round (score * 100);

			// Save the score, as a 1-100 integer
			targetMusicUnit.analysisScores.add (ParameterNames.HARMONIC_DISTRIBUTION,
					Math.max (ParameterCommons.MIN_LEGAL_SCORE, score));
		}

		/**
		 * Obtains information about the chord depicted by the provided Vector of MusicPitches:
		 * - the PLAYING pitches;
		 * - the number of playing pitches/voices;
		 * - the intervals between adjacent playing pitches (in semitones);
		 * - the size of the smallest interval available inside the chord
		 * @param chord
		 * @return
		 */
		private function _inspectChord(chord:Vector.<IMusicPitch>):Object {
			var info:Object = {
				numVoices: 0,
				smallestIntervalSize: int.MAX_VALUE,
				playingVoices: [],
				chordIntervals: []
			};
			chord = chord.concat().reverse();
			chord.forEach(function (pitch:IMusicPitch, i:int, v:Vector.<IMusicPitch>):void {

				// We only count those pitches having MIDI values greater than 0; by convention, MIDI `0`
				// stands for a musical rest (that particular voice does not play in this chord). We are only
				// interested in voices that play.
				var currMidiNote:int = pitch.midiNote;
				if (currMidiNote != 0) {
					info.playingVoices.push(currMidiNote);
					info.numVoices++;

					// By the same logic, the "next pitch" is actually the pitch of the closest playing voice
					var nextPitch:IMusicPitch = null;
					var testPitchOffset:int = 0;
					var testIndex:int;
					while (!nextPitch && testPitchOffset < v.length) {
						testPitchOffset++;
						testIndex = (i + testPitchOffset);
						if (testIndex < v.length) {
							nextPitch = v[testIndex];
						}
						if (nextPitch && nextPitch.midiNote == 0) {
							nextPitch = null;
						}
					}
					if (nextPitch) {
						var intervalSize:int = Math.abs(currMidiNote - nextPitch.midiNote);
						info.chordIntervals.push(intervalSize);
						if (intervalSize < info.smallestIntervalSize) {
							info.smallestIntervalSize = intervalSize;
						}
					}
				}
			});
			if (info.smallestIntervalSize == int.MAX_VALUE) {
				info.smallestIntervalSize = 0;
			}
			return info;
		}

		/**
		 * Computes the best and the worst scores a chord with given chord's number of voices and smallest interval
		 * would achieve and returns the delta as a positive value.
		 * [CHECKED]
		 */
		private static function _computeGamut(chordInfo:Object):Number {

			// Build the "best" and "worst" chords and compute their scores. We use triangular numbers to convey a
			// sense of a pyramidal shape.
			var idealIntervals:Array = [];
			var triangularIndex:int = chordInfo.smallestIntervalSize;
			var triangularNumber:int = NumberUtil.getTriangularNumber(triangularIndex);
			if (triangularNumber != triangularIndex) {
				idealIntervals.push(triangularIndex);
			}
			while (idealIntervals.length < chordInfo.numVoices) {
				idealIntervals.push(NumberUtil.getTriangularNumber(triangularIndex));
				triangularIndex++;
			}
			var idealRawScore:int = _computeRawScore(idealIntervals);
			var worstIntervals:Array = idealIntervals.concat();
			worstIntervals.reverse();
			var worstRawScore:int = _computeRawScore(worstIntervals);

			// Move the entire range out of the negative realm (if applicable) and return the delta.
			var scores:Array = [worstRawScore, idealRawScore];
			scores.sort();
			var smallestScore:int = (scores[0] as int);
			if (smallestScore < 0) {
				var offset:int = Math.abs(smallestScore);
				worstRawScore += offset;
				idealRawScore += offset;
			}
			return Math.abs(idealRawScore - worstRawScore);
		}

		/**
		 * Reduces values of an Array having at least three integer elements, by working from the Array's end toward its
		 * beginning and (1) removing the current element and placing in lieu the result of its subtraction to the
		 * element right before. If there is no element before the current one, then the Array is left less in length by
		 * one. The process repeats until there are only two elements in the Array, and they get summed and returned.
		 * The process does not start if the Array does not hold at least 3 elements (returned value is 0).
		 * [CHECKED]
		 */
		private static function _computeRawScore(intervals:Array):Number {
			if (intervals.length < 3) {
				return 0;
			}
			var source:Array = intervals.concat();
			var i:int;
			var currOperand:int;
			var pairOperand:int;
			var replacementVal:int;
			while (source.length > 2) {
				for (i = source.length - 1; i >= 0; i--) {
					currOperand = source.splice(i, 1);
					if (source[i - 1] !== undefined) {
						pairOperand = (source[i - 1] as int);
						replacementVal = (currOperand > pairOperand) ? i : (currOperand == pairOperand) ? 0 : -i;
						source.splice(i, 0, replacementVal);
					}
				}
			}
			return (source[0] as int) + (source[1] as int);
		}

		/**
		 * Represents given `rawScore` as a percent of the given `gamut`.
		 *
		 * NOTES:
		 * - the gamut is built against canonical best/worst pyramidal structures. In "real life", there might be chord
		 *   structures that are not pyramidal at all, or are "deformed pyramids", i.e., the pyramid's "walls" are
		 *   "curved". In this last case, the received `rawScore` will actually be higher than the `gamut`. Our
		 *   response is to apply a penalty that is proportional to the degree af "deformation" rather than ceiling the
		 *   value to `gamut`
		 * - since the gamut has been obtained by moving into the positive realm the negative half of the test score,
		 *   we will add half of the gamut to received `rawScore`.
		 *   [CHECKED]
		 */
		private static function _transposeScore(rawScore:Number, gamut:Number):Number {
			rawScore += (gamut * 0.5);
			if (rawScore > gamut) {
				var applicablePercent:Number = (gamut / rawScore);
				rawScore = (applicablePercent * gamut);
			}
			return (rawScore / gamut);
		}
	}
}
