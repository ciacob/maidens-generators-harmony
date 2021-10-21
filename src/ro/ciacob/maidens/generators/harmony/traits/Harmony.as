package ro.ciacob.maidens.generators.harmony.traits {
	import eu.claudius.iacob.music.knowledge.instruments.interfaces.IMusicalInstrument;

	import ro.ciacob.maidens.generators.core.AnalysisContext;
	import ro.ciacob.maidens.generators.core.abstracts.AbstractMusicalTrait;
	import ro.ciacob.maidens.generators.core.constants.CoreParameterNames;
	import ro.ciacob.maidens.generators.core.interfaces.IAnalysisContext;
	import ro.ciacob.maidens.generators.core.interfaces.IAnalysisScores;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicPitch;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalContentAnalyzer;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalPostProcessor;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalTrait;
	import ro.ciacob.maidens.generators.core.interfaces.IParameter;
	import ro.ciacob.maidens.generators.core.interfaces.IParametersList;
	import ro.ciacob.maidens.generators.core.interfaces.IPitchAllocation;
	import ro.ciacob.maidens.generators.core.interfaces.IRawMusicSource;
	import ro.ciacob.maidens.generators.core.interfaces.ISettingsList;
	import ro.ciacob.maidens.generators.harmony.analyzers.ChordProgression;
	import ro.ciacob.maidens.generators.harmony.analyzers.HarmonicDistribution;
	import ro.ciacob.maidens.generators.harmony.analyzers.IntrinsicConsonance;
	import ro.ciacob.maidens.generators.harmony.constants.ParameterCommons;
	import ro.ciacob.maidens.generators.harmony.sources.MultiCriterialChordSorter;
	import ro.ciacob.maidens.generators.harmony.sources.RandomChord;
	import ro.ciacob.utils.NumberUtil;

	public class Harmony extends AbstractMusicalTrait implements IMusicalTrait {

		// Initially, holds the class definitions of the IMusicalContentAnalyzer implementors to use. After initializing
		// each class, the resulting instance will be cached in this Array, replacing its corresponding class definition.
		private static const ANALYZERS:Array = [
			IntrinsicConsonance,
			ChordProgression,
			HarmonicDistribution
		];

		// Registry holding cached instances of IMusicalContentAnalyzers, by their name.
		private static const ANALYZERS_BY_NAME:Object = {};

		/**
		 * @constructor
		 * @see AbstractMusicalTrait
		 * @see IMusicalTrait
		 */
		public function Harmony() {
			super(this);
		}

		/**
		 * @see IMusicalTrait.execute
		 */
		override public function execute(targetMusicUnit:IMusicUnit, analysisContext:IAnalysisContext,
										 parameters:IParametersList, request:IMusicRequest):void {

			// Obtain current percent time, as an integer (1 to 100)
			var percentTime:Number = analysisContext.percentTime;
			var time:int = Math.round(percentTime * 100);
			var settings:ISettingsList = request.userSettings;

			// Generate and assess raw material. Only chords passing a preliminary validation/fitness
			// test are added as raw/potential chords. Chords are generated and validated one by one.
			var rawChords:Vector.<IMusicUnit> = new Vector.<IMusicUnit>;
			var rawSource:IRawMusicSource = new RandomChord;
			var winSizeParam:IParameter = parameters.getByName(
					CoreParameterNames.ANALYSIS_WINDOW)[0];
			var winSize:uint = settings.getValueAt(winSizeParam, percentTime) as uint;
			var heterogeneityParam:IParameter = parameters.getByName(
					CoreParameterNames.HETEROGENEITY)[0];
			var heterogeneity:uint = settings.getValueAt(heterogeneityParam, percentTime) as uint;
			var numChordsToTry:int = (winSize * heterogeneity);
			var numTries:int = numChordsToTry;

			// Starting 1.5.0, all randomly generated chords must pass a preliminary validation test in order to be even
			// considered for use. The test consists in comparing every chord score to its corresponding expected value, and
			// the resulting delta to a threshold, calculated based on a user configurable error margin.
			var errMarginParam:IParameter = parameters.getByName(CoreParameterNames.ERROR_MARGIN)[0];
			var errorMargin:Number = (settings.getValueAt(errMarginParam, percentTime) as uint) / 100;
			var i : int;
			var context:Object = {};

			$debug ('.');
			$debug ('-----------------------');
			$debug ('GENERATING ONE CHORD...')
			$debug ('-----------------------');
			do {
				// Generate one chord
				var possibleChord:IMusicUnit = rawSource.output(targetMusicUnit, analysisContext,
						parameters, request)[0];

				// Analyse it: analysis computes and stores chord scores within its `analysisScores`
				// property
				var analyzerEntry:Object;
				var analyzer:IMusicalContentAnalyzer;
				var normThreshold : Number =  Math.round(errorMargin * 100);
				$debug ('.');
				$debug ('------INITIALIZING AND RUNNING ANALYZERS------');
				for  (i = 0; i < ANALYZERS.length; i++) {
					analyzerEntry = (ANALYZERS[i] as Object);
					if (analyzerEntry is Class) {
						analyzer = (new (analyzerEntry as Class)) as IMusicalContentAnalyzer;
						ANALYZERS[i] = analyzer;
						ANALYZERS_BY_NAME[analyzer.name] = analyzer;
						$debug ('Initialized and cached', analyzer, 'from class', analyzerEntry);
						analyzer.threshold = normThreshold;
						$debug ('Initialized threshold for', analyzer, 'to', normThreshold);
					} else {
						analyzer = (analyzerEntry as IMusicalContentAnalyzer);
					}
					$debug ('Using cached:', analyzer);
					$debug ('Running', analyzer, 'with arguments:', possibleChord.pitches, analysisContext);
					analyzer.analyze(possibleChord, analysisContext, parameters, request);
					$debug (analyzer, 'analyzed', possibleChord.pitches, 'and produced score', possibleChord.analysisScores.getValueFor(analyzer.name));
				}

				// Only retain those chords whose scores ALL fall within a set threshold
				context.isValidChord = true;
				context.deltas = [];

				$debug ('------ASSESING ANALYSIS SCORES------');
				possibleChord.analysisScores.forEach(function (criteria:String, value:int):void {

					// If one of the score failed the test, don't do any more testing
					if (!context.isValidChord) {
						return;
					}

					// Note: since we are inside a closure, it is safer if we re-read these values instead of
					// using their snapshot stored at closure creation time; e.g., we prefer to re-read the
					// `percentTime` into a local variable.
					var pTime:int = Math.round(analysisContext.percentTime * 100);
					var parameter:IParameter = parameters.getByName(criteria)[0];

					// We skip checking contextual parameters at the beginning of the fragment, because there
					// is no context yet these parameters could refer to.
					if (value == ParameterCommons.NA_RESERVED_VALUE || (pTime == 0 && parameter.isContextual)) {
						return;
					}

					var uSettings:ISettingsList = request.userSettings;
					var expectedValue:Number = (uSettings.getValueAt(parameter, pTime) as uint);
					var delta:Number = Math.abs(value - expectedValue);
					context.deltas.push(delta);
					analyzer = (ANALYZERS_BY_NAME[criteria] as IMusicalContentAnalyzer);
					$debug ('Checking delta for ' + analyzer + ': ' + delta + '; analyzer.threshold is: ' + analyzer.threshold);
					if (delta >= analyzer.threshold) {
						context.isValidChord = false;
					}
					$debug ('Chord is valid:', context.isValidChord);
					$debug ((context.isValidChord? 'PASS' : 'FAIL'), 'Chord: [' + possibleChord.pitches + '] | Criteria:', criteria, '| value:', value, '| expectedValue:', expectedValue, '| delta:', delta, '|threshold:',  analyzer.threshold);
				});
				if (context.isValidChord) {
					rawChords.push(possibleChord);
					$debug ('Committing acceptable chord:', possibleChord);

					// If we collected at least one "perfect match", we end our search
					var averageDelta:Number = _average.apply(null, context.deltas);
					if (averageDelta == 0) {
						$debug ('Quick Exit Condition: found perfect chord:', possibleChord);
						break;
					}

					// If we collected at least `winSize` (i.e., the value of the ANALISIS_WINDOW
					// parameter) acceptable chords, exit as well.
					if (rawChords.length >= winSize) {
						$debug ('Quick Exit Condition: found at least', winSize, 'acceptable chords');
						break;
					}
				}
				numTries--;
				$debug ('Tries left:', numTries);

				// If we have exhausted the number of chords to be tried, yet we found no match,
				// that could mean the threshold cannot be met (in current context at least). Adjust
				// the threshold and try again.
				if (numTries == 0 && rawChords.length == 0) {
					$debug('----NO CHORDS PASSED. ADJUSTING THRESHOLD FOR ALL ANALYZERS----');
					var madeChanges : Boolean = false;
					for  (i = 0; i < ANALYZERS.length; i++) {
						analyzerEntry = (ANALYZERS[i] as Object);
						if (analyzerEntry is IMusicalContentAnalyzer) {
							analyzer = (analyzerEntry as IMusicalContentAnalyzer);
							if (analyzer.threshold < 100) {
								$debug (analyzer, 'from:', analyzer.threshold);
								analyzer.threshold = _convertHalvingToDoubling(analyzer.weight) * analyzer.threshold;
								$debug (analyzer, 'to:', analyzer.threshold);
								if (analyzer.threshold > 100) {
									analyzer.threshold = 100;
								}
								madeChanges = true;
							}
						}
					}
					if (madeChanges) {
						numTries = numChordsToTry;
					}
				}
			} while ((numTries > 0));
			$debug('DONE GENERATING; `rawChords` is:', rawChords.join('\n'));

			// Sort the chords, from fittest to most unsuitable
			var pickerSource:IRawMusicSource = new MultiCriterialChordSorter;
			var payload:IAnalysisContext = new AnalysisContext;
			payload.previousContent = rawChords;
			payload.percentTime = percentTime;
			var orderedChords:Vector.<IMusicUnit> = pickerSource.output(null, payload, parameters, request);

			// Pick one chord, also considering the "Hazard" Parameter
			var hazardParam:IParameter = parameters.getByName(CoreParameterNames.HAZARD)[0] as IParameter;
			var hazardPercent:Number = ((request.userSettings.getValueAt(hazardParam, time) as int) * 0.01) as Number;
			var sliceSize:int = (orderedChords.length * hazardPercent);
			sliceSize = Math.max(1, sliceSize);
			sliceSize = Math.min(orderedChords.length, sliceSize);
			orderedChords = orderedChords.slice(0, sliceSize);
			var chordIndex:int = NumberUtil.getRandomInteger(0, sliceSize - 1);
			var chosenChord:IMusicUnit = orderedChords[chordIndex];

			// Transfer the analysis scores to the target MusicUnit, for further reference and debug
			var srcScores:IAnalysisScores = chosenChord.analysisScores;
			var targetScores:IAnalysisScores = targetMusicUnit.analysisScores;
			var srcVal:int;
			if (!srcScores.isEmpty()) {
				srcScores.forEach(function (criteria:String, value:Number):Boolean {
					srcVal = srcScores.getValueFor(criteria) as int;
					targetScores.add(criteria, srcVal);
					return true;
				});
			}

			// Transfer pitches from the picked chord to the target MusicUnit. Note that transposing instruments are
			// NOT taken into account at this level. They are handled inside MAIDENS own code, right before writing
			// the score (and the MIDI file for playback).
			var srcPitches:Vector.<IMusicPitch> = chosenChord.pitches;
			var targetPitches:Vector.<IMusicPitch> = targetMusicUnit.pitches;
			targetPitches.length = 0;
			for (i = 0; i < srcPitches.length; i++) {
				targetPitches[i] = srcPitches[i];
			}

			// Also transfer allocations from the picked chord to the target MusicUnit, as at this stage, pitches have
			// already been distributed among available instruments.
			var srcAllocations:Vector.<IPitchAllocation> = chosenChord.pitchAllocations;
			var targetAllocations:Vector.<IPitchAllocation> = targetMusicUnit.pitchAllocations;
			targetAllocations.length = 0;
			for (i = 0; i < srcAllocations.length; i++) {
				targetAllocations[i] = srcAllocations[i];
			}
		}

		/**
		 * @see IMusicalTrait.musicalPostProcessors
		 */
		override public function get musicalPostProcessors():Vector.<IMusicalPostProcessor> {
			// TODO Auto Generated method stub
			return null;
		}

		/**
		 * Helper, computes the simple average of given values (useful since AS3 does not have an Array.reduce() method)
		 */
		private static function _average(...values):Number {
			var sum:Number = 0;
			var by:int = values.length;
			while (values.length) {
				var val:* = values.shift();
				sum += val;
			}
			return (sum / by);
		}

		/**
		 * Transposes a "less than one" factor into a "greater than one" factor, i.e., transposes "0.5" (a halving
		 * factor) to "1.5" (a doubling factor).
		 */
		private static function _convertHalvingToDoubling(factor:Number):Number {
			if (factor > 1) {
				return Math.min(2, factor);
			}
			return ((1 - factor) + 1);
		}

		/**
		 * Proxy that allows us to quickly turn logging on or off.
		 */
		private static function $debug (...args) : void {
			// trace.apply (trace, args);
		}
	}
}