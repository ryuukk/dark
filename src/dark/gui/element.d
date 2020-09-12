module dark.gui.element;

import dark.color;
import dark.math;
import dark.gui.stage;
import dark.gui.group;
import dark.gfx.batch;

public enum Touchable
{
    enabled,
    disabled,
    childrenOnly
}

public class Element
{
    private Stage stage;
    private Group parent;

    private string name;
    private Touchable touchable = Touchable.enabled;
    private bool visible = true;
    private bool debugg;

    private float x;
    private float y;
    private float width;
    private float height;
    private float originX;
    private float originY;
    private float scaleX = 1f;
    private float scaleY = 1f;
    private float rotation;
    private Color color = Color.WHITE;
    

    public void draw(SpriteBatch batcher, float parentAlpha)
    {}

    public void act(float dt)
    {}

    public Element hit(float x, float y, bool touchable)
    {
		if (touchable && touchable != Touchable.enabled) return null;
		if (!isVisible()) return null;
		return x >= 0 && x < width && y >= 0 && y < height ? this : null;
    }

    public void clear()
    {
        clearActions();
        clearListeners();
    }

    public Stage getStage()
    {
        return stage;
    }

    protected void setStage(Stage stage)
    {
        this.stage = stage;
    }

    public bool isDescendantOf(Element element)
    {
        assert(element !is null);
        Element parent = this;
		while (true) {
			if (parent == element) return true;
			parent = parent.parent;
			if (parent is null) return false;
		}
    }

    public bool isAscendantOf (Element element) {
        assert(element !is null);
		while (true) {
			if (element == this) return true;
			element = element.parent;
			if (element is null) return false;
		}
	}

    public void clearActions()
    {}

    public void clearListeners()
    {}

    public bool isVisible()
    {
        return isVisible;
    }
}