/**
 * User: booster
 * Date: 09/12/13
 * Time: 9:45
 */
package {
import starling.animation.Tween;
import starling.core.Starling;
import starling.display.Image;
import starling.display.Sprite;
import starling.events.Event;
import starling.shaders.FastGaussianBlurShader;
import starling.shaders.RenderTextureShader;
import starling.textures.Texture;
import starling.textures.TextureProcessor;

public class FastBlurDemo extends Sprite {
    [Embed(source="/starling_bird_transparent.png")]
    public static const Bird:Class;

    private var _birdTexture:Texture;

    private var _tempTextureA:Texture;
    private var _tempTextureB:Texture;

    private var _imageTexture:Texture;

    private var _renderTextureShader:RenderTextureShader    = new RenderTextureShader();
    private var _blurShader:FastGaussianBlurShader          = new FastGaussianBlurShader();
    private var _textureProcessor:TextureProcessor          = new TextureProcessor();

    public function FastBlurDemo() {
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    private function onAddedToStage(event:Event):void {
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        _birdTexture = Texture.fromBitmap(new Bird(), false);
        _tempTextureA = Texture.empty(_birdTexture.width, _birdTexture.height, true, false, true);
        _tempTextureB = Texture.empty(_birdTexture.width, _birdTexture.height, true, false, true);
        _imageTexture = Texture.empty(_birdTexture.width, _birdTexture.height, true, false, true);

        var image:Image = new Image(_imageTexture);
        addChild(image);

        // uncomment for a classic & slow gaussian blur
        //_blurShader.firstPassStrength = 1;
        //_blurShader.strengthIncreaseRatio = 1;

        _blurShader.strength = 0;

        var tween:Tween = new Tween(_blurShader, 5);
        tween.animate("strength", 30);
        tween.repeatCount = 0;
        tween.repeatDelay = 1;
        tween.reverse = true;
        Starling.juggler.add(tween);
    }

    private function onEnterFrame(event:Event):void {
        // render bird to tempA
        _textureProcessor.input = _birdTexture;
        _textureProcessor.output = _tempTextureA;
        _textureProcessor.shader = _renderTextureShader;
        _textureProcessor.process();

        // swap input and output
        _textureProcessor.swap();

        // render blur using tempA and tempB
        _textureProcessor.shader = _blurShader;
        _textureProcessor.output = _tempTextureB;

        _blurShader.pixelWidth      = 1 / _birdTexture.width;
        _blurShader.pixelHeight     = 1 / _birdTexture.height;

        // render passes
        for(var i:int = 0; i < _blurShader.passesNeeded; ++i) {
            _blurShader.pass = i;

            _blurShader.type = FastGaussianBlurShader.HORIZONTAL;

            _textureProcessor.process();
            _textureProcessor.swap();

            _blurShader.type = FastGaussianBlurShader.VERTICAL;

            _textureProcessor.process();
            _textureProcessor.swap();
        }

        // render to image
        _textureProcessor.output = _imageTexture;
        _textureProcessor.process();
    }
}
}
