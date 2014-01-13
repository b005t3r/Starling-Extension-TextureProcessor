/**
 * User: booster
 * Date: 13/01/14
 * Time: 9:40
 */
package starling.utils {

public class ExtendedVertexData extends VertexData {
    /** Same offset as for passing a color is used (COLOR_OFFSET)! Yes, it's a hack. */
    public static const UV_RANGE_OFFSET:int = COLOR_OFFSET;

    public function ExtendedVertexData(numVertices:int) {
        super(numVertices, false);
    }

    public function setUVRange(vertexID:int, minU:Number, maxU:Number, minV:Number, maxV:Number):void {
        var offset:int = vertexID * ELEMENTS_PER_VERTEX + COLOR_OFFSET;

        rawData[offset]             = minU;
        rawData[int(offset + 1)]    = maxU;
        rawData[int(offset + 2)]    = minV;
        rawData[int(offset + 3)]    = maxV;
    }
}
}
