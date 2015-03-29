/*
TVR - Terrific Visual Reporting
by Steven Goodwin, 2015
Released under the BSD 3 clause License
*/
import processing.serial.*;
import cc.arduino.*;

Arduino arduino;
tvrDisplaySettings displaySettings;



// TODO: widget frame, or something with linked list/vector
tvrWidget[] widgetDigitalList;
tvrAnalog[] widgetAnalogList;

void setup() {
  size(575, 310);

  println(Arduino.list()); 
   
  // Initialize the font & settings
  displaySettings = new tvrDisplaySettings();
  
  arduino = new Arduino(this, Arduino.list()[1], 57600);
  
  widgetDigitalList = new tvrWidget[14];

  for (int i = 0; i <= 13; i++) {
    arduino.pinMode(i, Arduino.INPUT);
    widgetDigitalList[i] = new tvrDigital(i, new tvrDigitalSettings(530 - i * 40, 10));
  }

  widgetAnalogList = new tvrAnalog[6];
  for(int i=0;i<6;++i) {
    widgetAnalogList[i] = new tvrAnalog(i, new tvrAnalogSettings(25+i*90, 120));
  }
  
}

void draw() {
  background(color(114, 179, 111));
  
  for (int i = 0; i <= 13; i++) {
    widgetDigitalList[i].injectState(arduino.digitalRead(i));
    widgetDigitalList[i].draw();
  }

  for(int i=0;i<6;++i) {
    widgetAnalogList[i].injectState(arduino.analogRead(i));
    widgetAnalogList[i].draw();
  }
}





// TVR library code below...



class tvrDisplaySettings {
  public static final int margin = 2;
  public static final int margin2 = margin * 2;
  PFont font;
  
  tvrDisplaySettings() {
    font = createFont("Georgia", 14);
    textFont(font);
  }
  
}


// Base class
class tvrWidget {
  tvrWidget(String name_) {
    name = name_;
    tracer = null;
    currentState = 0;
  }

  void injectState(int state) {
    previousState = currentState;
    currentState = state; 
      
    if (tracer != null) {
      tracer.injectState(state);
    }
  }
  
  // Q. is it useful to have multiple tracers for a widget?
  void addTracer(tvrTracer t) {
    tracer = t;
  }
  
  void draw() {
  }
  
  void drawUnit(tvrWidgetSettings settings) {
    drawFrame(settings);
    drawName(settings.x, settings.y);
    
    drawWidget();
    
    if (tracer != null) {
      tracer.draw();
    }
  }
  
  void drawName(int x, int y) {
    textAlign(LEFT, TOP);
    fill(previousState == currentState ? 0 : color(204, 29, 31));
    text(name, x, y);
  }
  
  void drawFrame(tvrWidgetSettings settings) {
    color colShadow = color(14, 14, 14);
    color colEdge = color(0, 0, 0);
    color colPaper = color(200, 200, 200);
    int shadowSize = 4;
    
    stroke(colShadow);
    fill(colShadow);
    rect(settings.x+shadowSize, settings.y+shadowSize, settings.width, settings.height);

    stroke(colEdge);
    fill(colPaper);
    rect(settings.x, settings.y, settings.width, settings.height);
  }
  
  void drawWidget() {
  }
  
  protected int                 currentState;
  private   int                 previousState;
  protected String              name;
  protected tvrTracer           tracer;
}

class tvrWidgetSettings {
  
  tvrWidgetSettings(int x_, int y_, int width_, int height_) {
    x = x_;
    y = y_;
    width = width_;
    height = height_;
  }
  
  
  public int x, y, width, height;
}

//
// Digital input Widget : Represents 0 and 1
//
class tvrDigitalSettings extends tvrWidgetSettings {
  tvrDigitalSettings(int x_, int y_, int width_, int height_) {
    super(x_, y_, width_, height_);
  }
  
  tvrDigitalSettings(int x_, int y_) {
    super(x_, y_, 32, 60);
  }
}

class tvrDigital extends tvrWidget {

  tvrDigital(int pin, tvrDigitalSettings settings_) {
    super("D" + str(pin));
    settings = settings_;
    
    addTracer(new tvrTracer(new tvrTracerSettings(settings.x+displaySettings.margin, settings.y+settings.height-(16+displaySettings.margin2), settings.width-displaySettings.margin2, 16)));
  }
 
  void draw() {
    super.drawUnit(settings);
  }
  
  void drawWidget() {
    color off = color(4, 79, 111);
    color on = color(84, 145, 158);   
    int indicatorHeight = 16;
    
    stroke(on);
    fill(currentState == Arduino.HIGH ? on : off);
    rect(settings.x+displaySettings.margin, settings.y+16, settings.width-displaySettings.margin2, indicatorHeight);
    
    if (currentState == Arduino.HIGH) {
      textAlign(CENTER, TOP);
      fill(0);
      text("1", settings.x+settings.width/2, settings.y+indicatorHeight);
    }
    
  }
  
  private tvrDigitalSettings   settings;
  
}


//
// Digital analog Widget : Represents values between 0 and 1023, to match Arduino
//

class tvrAnalogSettings extends tvrWidgetSettings {
  tvrAnalogSettings(int x_, int y_, int width_, int height_) {
    super(x_, y_, width_, height_);
  }
  
  tvrAnalogSettings(int x_, int y_) {
    super(x_, y_, 80, 160);
  }
}

class tvrAnalog extends tvrWidget {

  tvrAnalog(int pin, tvrAnalogSettings settings_) {
    super("A" + str(pin));
    
    settings = settings_;
    refreshPeriod = 1000;  // in ms
    minValueDrawn = minValueCached = range;
    maxValueDrawn = maxValueCached = 0;
 
    tvrTracerSettings ts = new tvrTracerSettings(settings.x+displaySettings.margin, settings.y+settings.height-(54+displaySettings.margin), settings.width-displaySettings.margin2, 54);
    addTracer(new tvrTracer(ts));

    setInputRange(1024);
    
    lastMilli = millis();
  }

  void setRefreshPeriod(int period) {
    refreshPeriod = period;
  }

  void setInputRange(int range_) {
    range = range_;
    tracer.setInputRange(range);
  }
  
  void injectState(int state) {
    super.injectState(state);
    
    minValueCached = min(state, minValueCached);
    maxValueCached = max(state, maxValueCached);
    
    if (millis() < lastMilli + refreshPeriod) { 
      return;
    }
    
    minValueDrawn = minValueCached;
    maxValueDrawn = maxValueCached;
    
    minValueCached = range;
    maxValueCached = 0;
   
    lastMilli = millis();
  }
  
  
  void draw() {
    super.drawUnit(settings);
  }
  
  void drawWidget() {
    color off = color(4, 79, 111);
    color on = color(84, 145, 158);   

    int indicatorBarWidth = 32;
    int indicatorBarHeight = settings.height - 80;  // space for the tracer
    int xpos = settings.x+settings.width-indicatorBarWidth-4;
    int ypos = settings.y + 8;
    
    
 
    // Draw the bar    
    int barHeight = (int)map(currentState, 0, range, 0, indicatorBarHeight);
    stroke(on);
    fill(color(4, 79, 111));
    rect(xpos, ypos, indicatorBarWidth, indicatorBarHeight);

    fill(color(200, 209, 211));
    rect(xpos+1, ypos+indicatorBarHeight-barHeight, indicatorBarWidth-2, barHeight);
    
    // Add markers to the bar
    stroke(color(255,255,255)); 
    strokeWeight(1);
    int minBar = ypos+indicatorBarHeight - (int)map(minValueDrawn, 0, range, 0, indicatorBarHeight);
    int maxBar = ypos+indicatorBarHeight - (int)map(maxValueDrawn, 0, range, 0, indicatorBarHeight);
    
    line(xpos-5, minBar, xpos+2, minBar);  
    line(xpos-5, maxBar, xpos+2, maxBar);  
    
    textAlign(LEFT, TOP);
    fill(color(0,0,0));
    text("=" + str(currentState), settings.x+4, settings.y+20);

    text("^" + str(maxValueDrawn), settings.x+4, settings.y+50);
    text("v" + str(minValueDrawn), settings.x+4, settings.y+70);
    
  }

  private tvrAnalogSettings settings;
  private int               range;
  private int               refreshPeriod;
  private int               minValueDrawn, minValueCached;
  private int               maxValueDrawn, maxValueCached;
  private long              lastMilli;

}



//
// Digital input Widget : Represents 0 and 1
//

class tvrTracerSettings extends tvrWidgetSettings {

  tvrTracerSettings(int x_, int y_, int width_, int height_) {
    super(x_, y_, width_, height_);
    
    samplingPeriod = 0;  // in milliseconds. 0= as often as possible
    inputRange = 1;
  }

  void setSamplingPeriod(int period) {
    samplingPeriod = period;
  }
  
  void setInputRange(int range) {
    inputRange = range;
  }
  
  int getInputRange() {
    return inputRange;
  }
  
  private int inputRange;
  private int samplingPeriod;
}

class tvrTracer extends tvrWidget {
  tvrTracer(tvrTracerSettings settings_) {
    super("");
    
    settings = settings_;

    buffer = new int[settings.width];  // TODO consider storing more data than can be seen, to allow zoom
    fromIdx = 0;
    lastIdx = 0;
    bUseAsCyclicBuffer = false;
    
    lastMilli = millis();
  }
   
  void injectState(int state) {
    state = max(state, 0);
    state = min(state, settings.getInputRange()); //<>//
      
    super.injectState(state);

    if (millis() >= lastMilli + settings.samplingPeriod) {   
      buffer[lastIdx] = state;
      if (++lastIdx == buffer.length) {
        lastIdx = 0;
        bUseAsCyclicBuffer = true;
      }
      
      if (bUseAsCyclicBuffer) {
        if (++fromIdx == buffer.length) {
          fromIdx = 0;
        }
      }
      
      lastMilli = millis();
    }
         
  }
  
  void setInputRange(int range) {
    settings.setInputRange(range);
  }
  
  
  void draw() {
    int x, y;
    int lx, ly;
    int count = (bUseAsCyclicBuffer) ? buffer.length : (lastIdx - fromIdx);
 
    // solid background
    color bg = color(24, 24, 24);   
    stroke(bg);
    fill(color(14, 79, 71));
    rect(settings.x, settings.y, settings.width, settings.height);

     // render the line
    stroke(color(255,255,255)); 
    strokeWeight(1);
    
    lx = x = settings.x; 
    // TODO: Fix this duplicated code!
    ly = settings.y + (int)map(buffer[0], 0, settings.inputRange, settings.height, 0);

    for(int i=fromIdx;count>1; --count, ++i) {  // we use >1 to stop the last line being drawn (which is a wrap of the 1st data point)
      i %= buffer.length;
      y = settings.y + (int)map(buffer[i], 0, settings.inputRange, settings.height, 0);

      // We draw two lines ensure rising/falling edges appear sharp, and not slopes
      line(lx, ly, x, ly);
      line(x, ly, x, y);
      
      lx = x;
      ly = y;
      
      ++x;
    }

  }
 
 private tvrTracerSettings   settings;
 private long                lastMilli;
 
 private int[]               buffer;
 private int                 fromIdx;
 private int                 lastIdx;
 private boolean             bUseAsCyclicBuffer;
}
