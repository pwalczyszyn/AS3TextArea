package com.riaspace.as3TextArea
{
	import flash.events.KeyboardEvent;
	import flash.events.TimerEvent;
	import flash.text.StyleSheet;
	import flash.ui.Keyboard;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import flashx.textLayout.conversion.ITextImporter;
	import flashx.textLayout.edit.SelectionState;
	import flashx.textLayout.elements.Configuration;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.formats.LineBreak;
	import flashx.textLayout.formats.TextLayoutFormat;
	import flashx.textLayout.operations.ApplyFormatOperation;
	import flashx.textLayout.operations.CompositeOperation;
	
	import spark.components.TextArea;
	import spark.components.TextSelectionHighlighting;
	import spark.events.TextOperationEvent;
	
	[Bindable]
	public class AS3TextArea extends TextArea
	{
		private static const TEXT_LAYOUT_NAMESPACE:String = "http://ns.adobe.com/textLayout/2008";
		
		public var keywords:Object =
			{
				accessModifiers : ["public", "private", "protected", "internal"],
				classMethodVariableModifiers : ["class", "const", "extends", "final", "function", "get", "dynamic", "implements", "interface", "native", "new", "set", "static"],
				flowControl : ["break", "case", "continue", "default", "do", "else", "for", "for\\seach", "if", "is", "label", "typeof", "return", "switch", "while", "in"],
				errorHandling : ["catch", "finally", "throw", "try"],
				packageControl : ["import", "package"],
				variableKeywords : ["super", "this", "var"],
				returnTypeKeyword : ["void"],
				namespaces : ["default xml namespace", "namespace", "use namespace"],
				literals : ["null", "true", "false"],
				primitives : ["Boolean", "int", "Number", "String", "uint"],
				strings : [/".*?"/, /'.*?'/],
				comments : [/\/\/.*$/, new RegExp("/\\\*[.\\w\\s]*\\\*/"), new RegExp("/\\\*([^*]|[\\r\\n]|(\\\*+([^*/]|[\\r\\n])))*\\\*/")],
				traceFunction : ["trace"]
			};
		
		public var defaultStyleSheet:String = ".text{color:#000000;font-family: courier;} .default{color:#0839ff;} .var{color:#80aad4;} .function{color:#55a97f;} .strings{color:#a82929;} .comment{color:#0e9e0f;font-style:italic;} .asDocComment{color:#5d78c9;} .traceFunction{color:#dc6066;}";
		
		protected var _syntaxStyleSheet:String;
		
		protected var syntax:RegExp;
		
		protected var styleSheet:StyleSheet = new StyleSheet();
		
		protected var importer:ITextImporter;
		
		protected var pseudoThread:Timer = new Timer(200, 1);
		
		protected var formats:Dictionary;
		
		public function AS3TextArea()
		{
			super();
			
			styleSheet.parseCSS(defaultStyleSheet);
			initSyntaxRegExp();
			initTextFlow();
			
			selectable = true;
			selectionHighlighting = TextSelectionHighlighting.ALWAYS;
			setStyle("lineBreak", LineBreak.EXPLICIT);
			
			addEventListener("textChanged", 
				function(event:Event):void 
				{
					trace("textChanged");
					colorize();
				});
			
			addEventListener(TextOperationEvent.CHANGE, 
				function(event:TextOperationEvent):void
				{
					trace("TextOperationEvent.CHANGE");
					if (!pseudoThread.running)
						pseudoThread.start();
				});
			
			addEventListener(KeyboardEvent.KEY_DOWN,
				function(event:KeyboardEvent):void
				{
					if (event.keyCode == Keyboard.TAB)
					{
						insertText(String.fromCharCode(Keyboard.TAB));
						focusManager.setFocus(
							focusManager.getNextFocusManagerComponent(true));
					}
				});
			
			pseudoThread.addEventListener(TimerEvent.TIMER, 
				function(event:TimerEvent):void
				{
					trace("TimerEvent.TIMER")
					colorize();
					pseudoThread.reset();
				});
		}
		
		protected function initTextFlow():void 
		{
			var config:Configuration = new Configuration();
			config.manageTabKey = true;
			
			config.textFlowInitialFormat = formats.text;
			textFlow = new TextFlow(config);
		}

		protected function initSyntaxRegExp():void 
		{
			formats  = new Dictionary();
			
			function getTokenTypeFormat(tokenType:String):TextLayoutFormat
			{
				var tokenStyleName:String = "." + tokenType;
				var tokenStyle:Object = 
					styleSheet.styleNames.indexOf(tokenStyleName) > -1
					?
					styleSheet.getStyle(tokenStyleName)
					:
					styleSheet.getStyle(".default");
				
				var result:TextLayoutFormat = new TextLayoutFormat();
				result.color = tokenStyle.color;
				result.fontFamily = tokenStyle.fontFamily;
				result.fontStyle = tokenStyle.fontStyle;
				result.fontWeight = tokenStyle.fontWeight;
				result.fontSize = tokenStyle.fontSize;
				
				return result;
			}
			
			var pattern:String = "";
			
			for (var type:String in keywords)
			{
				var typeKeywords:Array = keywords[type];
				for each(var keyword:Object in typeKeywords)
				{
					if (keyword is RegExp)
						pattern += RegExp(keyword).source + "|";
					else
						pattern += "\\b" + keyword + "\\b|"
				}
				
				formats[type] = getTokenTypeFormat(type);
			}
			
			// Initializing default text format
			formats["text"] = getTokenTypeFormat("text");
			
			if (pattern.charAt(pattern.length - 1) == "|")
				pattern = pattern.substr(0, pattern.length - 1);
			
			this.syntax = new RegExp(pattern, "gm");
		}
		
		protected function colorize():void
		{
			var stime:Number = new Date().time;
			// Creating new CompositeOperation
			var compositeOperation:CompositeOperation = new CompositeOperation();
			
			// Reseting whole text to the default TextLayoutFormat
			var operationState:SelectionState = new SelectionState(textFlow, 0, text.length);
			var formatOperation:ApplyFormatOperation = 
				new ApplyFormatOperation(operationState, formats.text, null);
			compositeOperation.addOperation(formatOperation);
			
			// Executing RegExp for the first token			
			var token:* = syntax.exec(this.text);
			while(token)
			{
				// Getting token value
				var tokenValue:String = token[0];
				// Detecting token type
				var tokenType:String = getTokenType(tokenValue);
				// Getting TextLayoutFormat for current token type
				var format:TextLayoutFormat = formats[tokenType]; 
				
				// Creating new SelectionState for at the location of current token
				operationState = new SelectionState(textFlow,
					token.index, token.index + tokenValue.length);
				
				// Creating new ApplyFormatOperation for current token
				formatOperation = new ApplyFormatOperation(operationState, 
					format, null);
				
				// Adding ApplyFormatOperation to CompositeOperation
				compositeOperation.addOperation(formatOperation);
				
				// Incrementing RegExp syntax lastIndex after the current token
				syntax.lastIndex = token.index + tokenValue.length;
				
				// Executing RegExp for the next token
				token = syntax.exec(this.text);
			}
			
			// Executing batch of ApplyFormatOperation's			
			var success:Boolean = compositeOperation.doOperation();
//			if (success)
//				textFlow.flowComposer.updateAllControllers();
			
			trace("Coloring done in:", new Date().time - stime, "ms");
		}
		
		protected function getTokenType(tokenValue:String):String
		{
			var result:String;
			if (tokenValue == "var")
			{
				return "var";
			}
			else if (tokenValue == "function")
			{
				return "function";
			}
			else if (tokenValue.indexOf("\"") == 0 || tokenValue.indexOf("'") == 0)
			{
				return "strings";
			}
			else if (tokenValue.indexOf("/**") == 0)
			{
				return "asDocComment";
			}
			else if (tokenValue.indexOf("//") == 0 || tokenValue.indexOf("/*") == 0)
			{
				return "comment";
			}
			else if (keywords.accessModifiers.indexOf(tokenValue) > -1)
			{
				return "accessModifiers";
			}
			else if (keywords.classMethodVariableModifiers.indexOf(tokenValue) > -1)
			{
				return "classMethodVariableModifiers";
			}
			else if (keywords.flowControl.indexOf(tokenValue) > -1)
			{
				return "flowControl";
			}
			else if (keywords.errorHandling.indexOf(tokenValue) > -1)
			{
				return "errorHandling";
			}
			else if (keywords.packageControl.indexOf(tokenValue) > -1)
			{
				return "packageControl";
			}
			else if (keywords.variableKeywords.indexOf(tokenValue) > -1)
			{
				return "variableKeywords";
			}
			else if (keywords.returnTypeKeyword.indexOf(tokenValue) > -1)
			{
				return "returnTypeKeyword";
			}
			else if (keywords.namespaces.indexOf(tokenValue) > -1)
			{
				return "namespaces";
			}
			else if (keywords.literals.indexOf(tokenValue) > -1)
			{
				return "literals";
			}
			else if (keywords.primitives.indexOf(tokenValue) > -1)
			{
				return "primitives";
			}
			else if (keywords.traceFunction.indexOf(tokenValue) > -1)
			{
				return "traceFunction";
			}

			return result;
		}
		
		public function get syntaxStyleSheet():String
		{
			return _syntaxStyleSheet;
		}
		
		public function set syntaxStyleSheet(value:String):void
		{
			_syntaxStyleSheet = value;
			
			styleSheet.clear();
			if (_syntaxStyleSheet)
				styleSheet.parseCSS(_syntaxStyleSheet);
			else
				styleSheet.parseCSS(defaultStyleSheet);
			
			var currentText:String = text;
			initSyntaxRegExp();
			initTextFlow();
			text = currentText;
		}
	}
}