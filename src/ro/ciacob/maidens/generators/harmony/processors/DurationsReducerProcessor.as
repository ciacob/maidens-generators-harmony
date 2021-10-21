package ro.ciacob.maidens.generators.harmony.processors {

	import ro.ciacob.math.Fraction;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalPostProcessor;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicalBody;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicRequest;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicUnit;
	import ro.ciacob.maidens.generators.core.interfaces.IMusicPitch;
	import ro.ciacob.maidens.generators.core.interfaces.IPitchAllocation;
	import ro.ciacob.maidens.generators.core.abstracts.AbstractMusicalPostProcessor;

	/**
	 * Detects same-pitch Notes found within the same Voice and adjacent Clusters
	 * and ties them, so that the right-hand Note is not "struck" anymore. This
	 * procedure may result in rudimentary polyphonic setups, which may improve
	 * the overal sounding of a generated homophonic choral.
	 * @see IMusicalPostProcessor
	 */
	public class DurationsReducerProcessor extends AbstractMusicalPostProcessor implements IMusicalPostProcessor {

		/**
		 * @see constructor
		 */
		public function DurationsReducerProcessor() {
			super(this);
		}

		/*
		 * @see IMusicalPostProcessor.execute
		 */
		override public function execute (rawMusicalBody : IMusicalBody, request : IMusicRequest) : void {

			var slice : Vector.<IMusicUnit> = new Vector.<IMusicUnit>;
			rawMusicalBody.forEach (function(unit : IMusicUnit, index : uint, ...etc) : void {
				slice.push (unit);
				if (slice.length > 2) {
					slice.reverse();
					slice.length = 2;
					slice.reverse();
				}
				if (slice.length == 2) {
					var leftUnit : IMusicUnit = slice[0];
					var rightUnit : IMusicUnit = slice[1];
					var leftPitches : Vector.<IMusicPitch> = leftUnit.pitches;
					var leftPitchAllocations : Vector.<IPitchAllocation> = leftUnit.pitchAllocations;
					var rightPitches : Vector.<IMusicPitch> = rightUnit.pitches;
					var rightPitchAllocations : Vector.<IPitchAllocation> = rightUnit.pitchAllocations;

					leftPitches.forEach (function (leftPitch : IMusicPitch, pitchIndex : uint, ...etc) : void {
						var rightPitch : IMusicPitch = null;
						var leftAllocation : IPitchAllocation = null;
						var rightAllocation : IPitchAllocation = null;
						if (pitchIndex < rightPitches.length) {
							rightPitch = rightPitches[pitchIndex];
						}
						if (pitchIndex < leftPitchAllocations.length) {
							leftAllocation = leftPitchAllocations[pitchIndex];
						}
						if (pitchIndex < rightPitchAllocations.length) {
							rightAllocation = rightPitchAllocations[pitchIndex];
						}
						if (leftPitch && rightPitch && leftAllocation && rightAllocation) {
							if (leftPitch.midiNote == rightPitch.midiNote &&
								leftAllocation.instrument == rightAllocation.instrument &&
								leftAllocation.voiceIndex == rightAllocation.voiceIndex) {
								leftPitch.tieNext = true;
								// trace ('have match:', leftPitch);
							}
						}
					});
				}
			});
		}
	}
}