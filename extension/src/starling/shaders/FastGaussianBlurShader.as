/**
 * User: booster
 * Date: 18/12/13
 * Time: 11:29
 */
package starling.shaders {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IField;
import com.barliesque.agal.IRegister;
import com.barliesque.agal.TextureFlag;

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

public class FastGaussianBlurShader extends EasierAGAL implements ITextureShader {
    public static const HORIZONTAL:String   = "horizontal";
    public static const VERTICAL:String     = "vertical";

    public static const DEFAULT_FIRST_PASS_STRENGTH:Number                 = 1.25;
    public static const DEFAULT_STRENGTH_INCREASE_PER_PASS_RATIO:Number    = 2.5;

    protected static const TEXTURE_FLAGS:Array = [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_LINEAR, TextureFlag.MIP_NO];

    private static var _verticalOffsets:Vector.<Number>     = new <Number>[0.0, 1.3846153846, 0.0, 3.2307692308];
    private static var _horizontalOffsets:Vector.<Number>   = new <Number>[1.3846153846, 0.0, 3.2307692308, 0.0];
    private static var _weights:Vector.<Number>             = new <Number>[0.2270270270, 0.3162162162, 0.0702702703, 0];

    private var _type:String                    = HORIZONTAL;
    private var _pass:int                       = 0;
    private var _strength:Number                = Number.NaN;
    private var _firstPassStrength:Number       = DEFAULT_FIRST_PASS_STRENGTH;
    private var _strengthIncreaseRatio:Number   = DEFAULT_STRENGTH_INCREASE_PER_PASS_RATIO;
    private var _paramsDirty:Boolean            = true;
    private var _strengthsDirty:Boolean         = true;

    protected var _strengths:Vector.<Number>    = new <Number>[];
    private var _offsets:Vector.<Number>        = new <Number>[0, 0, 0, 0];
    private var _uv:Vector.<Number>             = new <Number>[0, 1, 0, 1];
    private var _pixelSize:Vector.<Number>      = new <Number>[Number.NaN, Number.NaN, Number.NaN, Number.NaN];

    // shader constants
    protected var uvCenter:IRegister            = VARYING[0];
    protected var weightCenter:IComponent       = CONST[0].x;
    protected var weightOne:IComponent          = CONST[0].y;
    protected var weightTwo:IComponent          = CONST[0].z;
    protected var offsetOne:IField              = CONST[1].xy;
    protected var offsetTwo:IField              = CONST[1].zw;
    protected var uMin:IComponent               = CONST[2].x;
    protected var uMax:IComponent               = CONST[2].y;
    protected var vMin:IComponent               = CONST[2].z;
    protected var vMax:IComponent               = CONST[2].w;
    protected var halfPixelWidth:IComponent     = CONST[3].z;
    protected var halfPixelHeight:IComponent    = CONST[3].w;

    public function get type():String { return _type; }
    public function set type(value:String):void {
        if(value == _type)
            return;

        _type = value;
        _paramsDirty = true;
    }

    public function get strength():Number { return _strength; }
    public function set strength(value:Number):void {
        if(value == _strength)
            return;

        _strength = value;
        _paramsDirty = true;
        _strengthsDirty = true;
    }

    public function get firstPassStrength():Number { return _firstPassStrength; }
    public function set firstPassStrength(value:Number):void {
        if(_firstPassStrength == value)
            return;

        _firstPassStrength = value;
        _paramsDirty = true;
        _strengthsDirty = true;
    }

    public function get strengthIncreaseRatio():Number { return _strengthIncreaseRatio; }
    public function set strengthIncreaseRatio(value:Number):void {
        if(_strengthIncreaseRatio == value)
            return;

        _strengthIncreaseRatio = value;
        _paramsDirty = true;
        _strengthsDirty = true;
    }

    public function get pass():int { return _pass; }
    public function set pass(value:int):void {
        if(value == _pass)
            return;

        _pass = value;
        _paramsDirty = true;
    }

    public function get pixelWidth():Number { return _pixelSize[0]; }
    public function set pixelWidth(value:Number):void {
        if(value == _pixelSize[0])
            return;

        _pixelSize[0] = value;
        _pixelSize[2] = value / 2;
        _paramsDirty = true;
    }

    public function get pixelHeight():Number { return _pixelSize[1]; }
    public function set pixelHeight(value:Number):void {
        if(value == _pixelSize[1])
            return;

        _pixelSize[1] = value;
        _pixelSize[3] = value / 2;
        _paramsDirty = true;
    }

    public function get passesNeeded():int {
        if(_strengthsDirty)
            updateStrengths();

        return _strengths.length;
    }

    public function get minU():Number { return _uv[0]; }
    public function set minU(value:Number):void { _uv[0] = value; }

    public function get maxU():Number { return _uv[1]; }
    public function set maxU(value:Number):void { _uv[1] = value; }

    public function get minV():Number { return _uv[2]; }
    public function set minV(value:Number):void { _uv[2] = value; }

    public function get maxV():Number { return _uv[3]; }
    public function set maxV(value:Number):void { _uv[3] = value; }

    public function activate(context:Context3D):void {
        if(_strengthsDirty)
            updateStrengths();

        if(_paramsDirty)
            updateParameters();

        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _weights);
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, _offsets);
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, _uv);
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, _pixelSize);
    }

    public function deactivate(context:Context3D):void { }

    override protected function _vertexShader():void {
        comment("Apply a 4x4 matrix to transform vertices to clip-space");
        multiply4x4(OUTPUT, ATTRIBUTE[0], CONST[0]);

        comment("Pass uv coordinates to fragment shader");
        move(uvCenter, ATTRIBUTE[1]);
    }

    override protected function _fragmentShader():void {
        var tempColor:IRegister     = TEMP[0];
        var outputColor:IRegister   = TEMP[1];
        var uv:IRegister            = TEMP[2];

        sampleColor(outputColor, uvCenter, weightCenter);

        subtract(uv, uvCenter, offsetTwo);
        sampleColor(tempColor, uv, weightTwo, uMin, uMax, vMin, vMax, halfPixelWidth, halfPixelHeight, TEMP[6]);
        add(outputColor, outputColor, tempColor);

        subtract(uv, uvCenter, offsetOne);
        sampleColor(tempColor, uv, weightOne, uMin, uMax, vMin, vMax, halfPixelWidth, halfPixelHeight, TEMP[6]);
        add(outputColor, outputColor, tempColor);

        add(uv, uvCenter, offsetOne);
        sampleColor(tempColor, uv, weightOne, uMin, uMax, vMin, vMax, halfPixelWidth, halfPixelHeight, TEMP[6]);
        add(outputColor, outputColor, tempColor);

        add(uv, uvCenter, offsetTwo);
        sampleColor(tempColor, uv, weightTwo, uMin, uMax, vMin, vMax, halfPixelWidth, halfPixelHeight, TEMP[6]);
        add(outputColor, outputColor, tempColor);

        move(OUTPUT, outputColor);
    }

    protected function sampleColor(sampledColor:IRegister, uv:IRegister, colorWeight:IComponent, minU:IComponent = null, maxU:IComponent = null, minV:IComponent = null, maxV:IComponent = null, halfPixelWidth:IComponent = null, halfPixelHeight:IComponent = null, temp:IRegister = null):void {
        if(minU != null) {
            ShaderUtil.clamp(uv.x, minU, maxU, halfPixelWidth, temp);
            ShaderUtil.clamp(uv.y, minV, maxV, halfPixelHeight, temp);
        }

        sampleTexture(sampledColor, uv, SAMPLER[0], TEXTURE_FLAGS);
        multiply(sampledColor, sampledColor, colorWeight);
    }

    private function updateParameters():void {
        // algorithm described here:
        // http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
        //
        // To run in constrained mode, we can only make 5 texture lookups in the fragment
        // shader. By making use of linear texture sampling, we can produce similar output
        // to what would be 9 lookups.

        _paramsDirty = false;

        var multiplier:Number, str:Number = _strengths[_pass];
        var i:int, count:int = 4;

        if(type == HORIZONTAL) {
            multiplier = pixelWidth * str;

            for(i = 0; i < count; i++)
                _offsets[i] = _horizontalOffsets[i] * multiplier;
        }
        else {
            multiplier = pixelHeight * str;

            for(i = 0; i < count; i++)
                _offsets[i] = _verticalOffsets[i] * multiplier;
        }

        //trace("str: " + str);
    }

    private function updateStrengths():void {
        _strengthsDirty = false;

        _strengths.length   = 0;
        var str:Number      = Math.min(_firstPassStrength, _strength);
        var sum:Number      = 0;

        while(sum + str < _strength) {
            _strengths[_strengths.length] = str;
            sum += str;
            str *= _strengthIncreaseRatio;
        }

        var diff:Number = _strength - sum;

        if(diff > 0 || _strengths.length == 0)
            _strengths[_strengths.length] = diff;

        _strengths.sort(function (a:Number, b:Number):Number { return b - a; });

        //trace("strengths: [" + _strengths + "], total: " + _strength);
    }
}
}
