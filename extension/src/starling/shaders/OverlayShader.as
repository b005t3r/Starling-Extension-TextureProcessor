/**
 * User: booster
 * Date: 10/01/14
 * Time: 11:22
 */
package starling.shaders {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IRegister;
import com.barliesque.agal.IRegister;
import com.barliesque.agal.TextureFlag;
import com.barliesque.shaders.macro.Blend;

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

import starling.textures.Texture;

public class OverlayShader extends EasierAGAL implements ITextureShader {
    private static var _shaderConstants:Vector.<Number> = new <Number>[0.5, 1, 0, 0];

    private var _topTexture:Texture;

    public function activate(context:Context3D):void {
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _shaderConstants);

        context.setTextureAt(1, _topTexture.base); // fs1, fs0 is already set
    }

    public function deactivate(context:Context3D):void {
        context.setTextureAt(1, null);
    }

    public function get topTexture():Texture { return _topTexture; }
    public function set topTexture(value:Texture):void { _topTexture = value; }

    override protected function _vertexShader():void {
        comment("Apply a 4x4 matrix to transform vertices to clip-space");
        multiply4x4(OUTPUT, ATTRIBUTE[0], CONST[0]);

        comment("Pass uv coordinates to fragment shader");
        move(VARYING[0], ATTRIBUTE[1]);
    }

    override protected function _fragmentShader():void {
        var textureFlags:Array      = [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_LINEAR, TextureFlag.MIP_NO];
        var bottomColor:IRegister   = TEMP[1];
        var topColor:IRegister      = TEMP[2];
        var outputColor:IRegister   = TEMP[3];
        var half:IComponent         = CONST[0].x;
        var one:IComponent          = CONST[0].y;

        comment("sample the bottom texture");
        sampleTexture(bottomColor, VARYING[0], SAMPLER[0], textureFlags);

        comment("sample the top texture");
        sampleTexture(topColor, VARYING[0], SAMPLER[1], textureFlags);

        Blend.overlay(outputColor, bottomColor, topColor, one, half, TEMP[4], TEMP[5], TEMP[6]);
        move(outputColor.a, one);
        move(OUTPUT, outputColor);
    }
}
}
