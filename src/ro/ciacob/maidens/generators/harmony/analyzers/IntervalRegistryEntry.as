package ro.ciacob.maidens.generators.harmony.analyzers {
import eu.claudius.iacob.music.knowledge.harmony.IntervalRootPositions;
import eu.claudius.iacob.music.knowledge.harmony.Intervals;


public class IntervalRegistryEntry {
    private var _low:uint;
    private var _size:uint;
    private var _root:uint;

    public function IntervalRegistryEntry(low:uint, size:uint) {
        _low = low;
        _size = size;
        var rootPlacement:int = Intervals.getHindemithsIntervalRoot(size);
        _root = ((rootPlacement == IntervalRootPositions.BOTTOM) ? low :
                (rootPlacement == IntervalRootPositions.TOP) ? low + size :
                        int.MAX_VALUE);
    }

    public function get low():uint {
        return _low;
    };

    public function get size():uint {
        return _size;
    };

    public function get root():uint {
        return _root;
    }

    public function toString() : String {
        return ('Interval Registry Entry: low=' + _low + ' | size=' + _size + ' | root=' + _root);
    }
}
}
