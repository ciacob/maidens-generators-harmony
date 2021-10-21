package ro.ciacob.maidens.generators.harmony.sources {
    import eu.claudius.iacob.music.knowledge.instruments.interfaces.IMusicalInstrument;

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

    /**
     * Concrete IMusicalPrimitiveSource implementation that one unique random chord
     * within given low and high thresholds.
     */
    public class RandomChord extends AbstractRawMusicSource implements IRawMusicSource {

        // Class lifetime cache for the `_getTotalNumVoices()` function
        private var _totalNumVoices : int;

        // Class lifetime cache for the `_getAverageMiddleRange()` function
        private var _averageMiddleRange : Vector.<int>;

        // Class lifetime cache  for the `_getHighestAvailablePitch()` function
        private var _highestAvailablePitch : int;

        // Class lifetime cache for the `_getLowestAvailablePitch()` function
        private var _lowestAvailablePitch : int;

        /**
         * @constructor
         */
        public function RandomChord () {
            super (this);
        }

        /**
         * @see IMusicalPrimitiveSource.output
         */
        override public function output (targetMusicUnit:IMusicUnit,
                                         analysisContext:IAnalysisContext,
                                         parameters : IParametersList,
                                         request:IMusicRequest) : Vector.<IMusicUnit> {

            // GRAB CONTEXT
            var percentTime : int = Math.round (analysisContext.percentTime * 100);
            var getParam : Function = parameters.getByName;
            var settings : ISettingsList = request.userSettings;
            var instruments : Vector.<IMusicalInstrument> = request.instruments;

            // We need to internally reorder available instruments based on their center pitch, so that if we have e.g.,
            // brass ordered as  Horns, Trumpets, Trombone and Tuba (traditional score ordering) we are still able to
            // deliver the highest notes of a chord to Trumpets, then the mid and mid/low notes to Horns and, the low
            // notes to Trombones and Tuba, just as if the instruments were ordered as Trumpets, Horns, Trombones and
            // Tuba (contemporary score ordering).
            instruments = CommonMusicUtils.cloneAndReorderInstruments (instruments);

            // GRAB PARAMETERS' VALUES
            // Chord range
            var lowestParam : IParameter = getParam (ParameterNames.LOWEST_PITCH)[0];
            var lowestPercent : Number = ((settings.getValueAt (lowestParam, percentTime) as uint) * 0.01) as Number;
            var highestParam : IParameter = getParam (ParameterNames.HIGHEST_PITCH)[0];
            var highestPercent : Number = ((settings.getValueAt (highestParam, percentTime) as uint) * 0.01) as Number;
            var middleRange : Vector.<int> = _getAverageMiddleRange (instruments);
            var highestPitch : int = _getHighestAvailablePitch (instruments);
            var lowestPitch : int = _getLowestAvailablePitch (instruments);
            var highest : int = middleRange[1] + Math.round (highestPercent * (highestPitch - middleRange[1]));
            var lowest : int = lowestPitch + Math.round (lowestPercent * (middleRange[0] - lowestPitch));

            // Number of pitches in the chord
            var numVoicesParam : IParameter = getParam (ParameterNames.VOICES_NUMBER)[0];
            var numVoicesPercent : Number = ((settings.getValueAt(numVoicesParam, percentTime) as uint) * 0.01) as Number;
            var maxNumVoices : int = _getTotalNumVoices (instruments);
            var numVoices : int = (maxNumVoices >= 2)? Math.max (CoreOperationKeys.MIN_NUM_VOICES,
                    Math.ceil (numVoicesPercent * maxNumVoices)) : 1;

            // Build pitches table (must be rebuilt because the `high` and `low` limits might have changed)
            var allPitches : Array = new Array (highest - lowest + 1);
            for (var midiPitch : int = lowest, counter : int = 0; midiPitch <= highest; midiPitch++) {
                allPitches[counter++] = midiPitch;
            }

            // Build „range zones", based on the total number of available voices.
            // NOTE: it is important whether a voice will occupy half of a staff or the entire staff. Some instruments
            // combine both situations.
            // TODO: refactor based on the above observation.
            var rangeZones : Array = [];
            var zoneSize : uint = Math.ceil(allPitches.length / _totalNumVoices);
            while (allPitches.length > 0) {
                rangeZones.push (allPitches.splice (0, zoneSize));
            }

            // Adjust the range zones to fit inside the range of the corresponding instrument.
            var rangeZonesClone : Array = rangeZones.concat();
            for (var revIndex : int = instruments.length - 1; revIndex >= 0; revIndex--) {
                var instrument : IMusicalInstrument = instruments[revIndex];
                var instNumVoices : int = instrument.maximumAutonomousVoices;
                var instHighest : int = instrument.midiRange[1];
                var instLowest : int = instrument.midiRange[0];
                var instrumentZones : Array = rangeZonesClone.splice(0, instNumVoices);

                instrumentZones.forEach (function (zone: Array, voiceIndex : int, ...etc) : void {
                    var spliceArgs : Array = zone.filter (function (midiPitch : int, ...etc) : Boolean {
                        return (midiPitch >= instLowest && midiPitch <= instHighest);
                    });
                    spliceArgs.unshift(zone.length);
                    spliceArgs.unshift(0);
                    zone.splice.apply (zone, spliceArgs);

                    // N.B.: storing static properties on an Array of integers/MIDI pitches.
                    // MAIDENS laids out voices from top to bottom; as our Array has the bass zone in first index, we
                    // need to report voices in reverse order.
                    zone.instrument = instrument;
                    zone.voiceIndex = (instrumentZones.length - 1 - voiceIndex);
                });
            }

            // Build and return one unique random chord. It needs to be returned inside a Vector
            // for consistency with the Interface we are implementing.
            var output : Vector.<IMusicUnit> = new Vector.<IMusicUnit>;

            // Based on the current number of voices that we must use, randomly employ one or more of
            // the range zones built above. For consistency, maintain the zones order and their total
            // number (use zero-element zones as placeholders).
            var zoneIndex : int;
            var zoneIndices : Array = [];
            for (zoneIndex = 0; zoneIndex < rangeZones.length; zoneIndex++) {
                zoneIndices.push (zoneIndex);
            }
            var zoneIndicesToUse : Array = Arrays.getSubsetOf (zoneIndices, Math.min (zoneIndices.length, numVoices));
            var zonesToUse : Array = [];
            for (zoneIndex = 0; zoneIndex < rangeZones.length; zoneIndex++) {
                if (zoneIndicesToUse.indexOf(zoneIndex) != -1) {
                    zonesToUse[zoneIndex] = rangeZones[zoneIndex];
                } else {
                    var placeHolder : Array = [];
                    zonesToUse[zoneIndex] = placeHolder;

                    // Recover zone instrument and voice index from original zone
                    var skippedZone : Array = rangeZones[zoneIndex] as Array;
                    placeHolder.instrument = skippedZone.instrument;
                    placeHolder.voiceIndex = skippedZone.voiceIndex;
                }
            }

            // Randomly pick a MIDI value from each eligible zone. Use the reserved MIDI pitch `0` for
            // non eligible zones. When rendering to score, all `0` MIDI pitches will be translated to
            // rests.
            // We transfer chosen pitches to a MusicUnit (as this is the standardized vehicle we use to carry any type
            // of information).
            //
            // NOTE:
            // We previously have internally sorted instruments based on their relative pitch and score order rules, and
            // have assigned pitches to our chord/MusicUnit based on this sorted order. However, in the score,
            // instruments might be in any order. We now need to explicitely give pitch allocation rules, so that each
            // pitch eventually reaches its intended instrument.
            var	tmpMusicUnit : IMusicUnit = new MusicUnit;
            var tmpPitches : Vector.<IMusicPitch> = tmpMusicUnit.pitches;
            var tmpAllocations : Vector.<IPitchAllocation> = tmpMusicUnit.pitchAllocations;
            zonesToUse.forEach (function (zone : Array, ...etc) : void {
                var pitch : IMusicPitch = new MusicPitch;
                if (zone.length > 0) {
                    pitch.midiNote = (Arrays.getRandomItem(zone) as int);
                } else {
                    pitch.midiNote = 0;
                }
                tmpPitches.push (pitch);
                var allocation : IPitchAllocation = new PitchAllocation (zone.instrument as IMusicalInstrument,
                        zone.voiceIndex as int, pitch);
                tmpAllocations.push (allocation);
            });
            output.push (tmpMusicUnit);
            return  Vector.<IMusicUnit>(output);
        }

        /**
         * Resets local cache before class' end of life, in case this is needed.
         * @see IRawMusicSource.reset
         */
        override public function reset () : void {
            _totalNumVoices = 0;
            _averageMiddleRange = null;
            _highestAvailablePitch = 0;
            _lowestAvailablePitch = 0;
        }

        private function _compareRangeZones (zoneA : Array, zoneB : Array) : int {
            return (zoneA[0] - zoneB[0]);
        }

        /**
         * Returns the total number of polyphonic voices the instruments currently in use can provide.
         * Results are cached.
         */
        private function _getTotalNumVoices (instruments : Vector.<IMusicalInstrument>) : int {
            if (!_totalNumVoices) {
                for (var i:int = 0; i < instruments.length; i++) {
                    var instrument : IMusicalInstrument = instruments[i];
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
        private function _getAverageMiddleRange (instruments : Vector.<IMusicalInstrument>) : Vector.<int> {
            if (!_averageMiddleRange) {
                var lowLimitSum : int = 0;
                var highLimitSum : int = 0;
                var i : int;
                var instrument : IMusicalInstrument;
                for (i = 0; i < instruments.length; i++) {
                    instrument = instruments[i];
                    lowLimitSum += instrument.idealHarmonicRange[0];
                    highLimitSum += instrument.idealHarmonicRange[1];
                }
                var lowLimitAverage : int = Math.ceil (lowLimitSum / instruments.length);
                var highLimitAverage : int = Math.floor (highLimitSum / instruments.length);
                _averageMiddleRange = Vector.<int>([lowLimitAverage, highLimitAverage]);
            }
            return _averageMiddleRange;
        }

        /**
         * Returns the highest pitch any of the instruments currently in use is able to produce.
         */
        private function _getHighestAvailablePitch (instruments : Vector.<IMusicalInstrument>) : int {
            if (!_highestAvailablePitch) {
                var i : int;
                var instrument : IMusicalInstrument;
                var localHighest : int;
                var globalHighestPitch : int = 0;
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
        private function _getLowestAvailablePitch (instruments : Vector.<IMusicalInstrument>) : int {
            if (!_lowestAvailablePitch) {
                var i : int;
                var instrument : IMusicalInstrument;
                var localLowest : int;
                var globalLowestPitch : int = int.MAX_VALUE;
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
