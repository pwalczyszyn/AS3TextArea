package com.riaspace.as3TextArea
{
	import flash.events.TimerEvent;
	import flash.text.StyleSheet;
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
		
		public var accessModifiers:Array = ["public", "private", "protected", "internal"];
		
		public var classMethodVariableModifiers:Array = ["class", "const", "extends", "final", "function", "get", "dynamic", "implements", "interface", "native", "new", "set", "static"]; 
		
		public var flowControl:Array = ["break", "case", "continue", "default", "do", "else", "for", "for\\seach", "if", "is", "label", "typeof", "return", "switch", "while", "in"];
		
		public var errorHandling:Array = ["catch", "finally", "throw", "try"];
		
		public var packageControl:Array = ["import", "package"];
		
		public var variableKeywords:Array = ["super", "this", "var"];
		
		public var returnTypeKeyword:Array = ["void"];
		
		public var namespaces:Array = ["default xml namespace", "namespace", "use namespace"];
		
		public var literals:Array = ["null", "true", "false"];
		
		public var primitives:Array = ["Boolean", "int", "Number", "String", "uint"];
		
		public var strings:Array = ['".*?"', "'.*?'"];
		
		public var comments:Array = ["//.*$", "/\\\*[.\\w\\s]*\\\*/", "/\\\*([^*]|[\\r\\n]|(\\\*+([^*/]|[\\r\\n])))*\\\*/"];
		
		public var defaultStyleSheet:String = ".text{color:#000000;font-family: courier;} .default{color:#0839ff;} .var{color:#80aad4;} .function{color:#55a97f;} .strings{color:#a82929;} .comment{color:#0e9e0f;font-style:italic;} .asDocComment{color:#5d78c9;}";
		
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
			initTokenTypeFormats();
			initTextFlow();
			
			initSyntaxRegExp();
			
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

		protected function initTokenTypeFormats():void
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
			
			formats["text"] = getTokenTypeFormat("text");
			formats["var"] = getTokenTypeFormat("var");
			formats["function"] = getTokenTypeFormat("function");
			formats["strings"] = getTokenTypeFormat("strings");
			formats["asDocComment"] = getTokenTypeFormat("asDocComment");
			formats["comment"] = getTokenTypeFormat("comment");
			formats["accessModifiers"] = getTokenTypeFormat("accessModifiers");
			formats["classMethodVariableModifiers"] = 
				getTokenTypeFormat("classMethodVariableModifiers");
			formats["flowControl"] = getTokenTypeFormat("flowControl");
			formats["errorHandling"] = getTokenTypeFormat("errorHandling");
			formats["packageControl"] = getTokenTypeFormat("packageControl");
			formats["variableKeywords"] = getTokenTypeFormat("variableKeywords");
			formats["returnTypeKeyword"] = getTokenTypeFormat("returnTypeKeyword");
			formats["namespaces"] = getTokenTypeFormat("namespaces");
			formats["literals"] = getTokenTypeFormat("literals");
			formats["primitives"] = getTokenTypeFormat("primitives");
		}
		
		protected function initSyntaxRegExp():void 
		{
			var pattern:String = "";
			
			for each(var str:String in strings.concat(comments))
			{
				pattern += str + "|";
			}
			
			var createRegExp:Function = function(keywords:Array):String
			{
				var result:String = "";
				for each(var keyword:String in keywords)
				{
					result += (result != "" ? "|" : "") + "\\b" + keyword + "\\b";
				}
				return result;
			};
			
			pattern += createRegExp(accessModifiers)
				+ "|" 
				+ createRegExp(classMethodVariableModifiers)
				+ "|"
				+ createRegExp(flowControl)
				+ "|"
				+ createRegExp(errorHandling)
				+ "|"
				+ createRegExp(packageControl)
				+ "|"
				+ createRegExp(variableKeywords)
				+ "|"
				+ createRegExp(returnTypeKeyword)
				+ "|"
				+ createRegExp(namespaces)
				+ "|"
				+ createRegExp(literals)
				+ "|"
				+ createRegExp(primitives);
			
			this.syntax = new RegExp(pattern, "gm");
		}
		
		protected function colorize():void
		{
			var stime:Number = new Date().time;
			var compositeOperation:CompositeOperation = new CompositeOperation();

			var operationState:SelectionState = new SelectionState(textFlow,
				0, text.length);
			var formatOperation:ApplyFormatOperation =
				new ApplyFormatOperation(operationState, formats.text, null);
			compositeOperation.addOperation(formatOperation);
			
			var token:* = syntax.exec(this.text);
			while(token)
			{
				var tokenValue:String = token[0];
				var tokenType:String = getTokenType(tokenValue);
				var format:TextLayoutFormat = formats[tokenType]; 

				operationState = new SelectionState(textFlow,
					token.index, token.index + tokenValue.length);
				
				formatOperation = new ApplyFormatOperation(operationState, 
					format, null);
				
				compositeOperation.addOperation(formatOperation);

				syntax.lastIndex = token.index + tokenValue.length;
				token = syntax.exec(this.text);
			}
			
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
			else if (accessModifiers.indexOf(tokenValue) > -1)
			{
				return "accessModifiers";
			}
			else if (classMethodVariableModifiers.indexOf(tokenValue) > -1)
			{
				return "classMethodVariableModifiers";
			}
			else if (flowControl.indexOf(tokenValue) > -1)
			{
				return "flowControl";
			}
			else if (errorHandling.indexOf(tokenValue) > -1)
			{
				return "errorHandling";
			}
			else if (packageControl.indexOf(tokenValue) > -1)
			{
				return "packageControl";
			}
			else if (variableKeywords.indexOf(tokenValue) > -1)
			{
				return "variableKeywords";
			}
			else if (returnTypeKeyword.indexOf(tokenValue) > -1)
			{
				return "returnTypeKeyword";
			}
			else if (namespaces.indexOf(tokenValue) > -1)
			{
				return "namespaces";
			}
			else if (literals.indexOf(tokenValue) > -1)
			{
				return "literals";
			}
			else if (primitives.indexOf(tokenValue) > -1)
			{
				return "primitives";
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
			
			initTokenTypeFormats();
			initTextFlow();
			
			text = currentText;
		}
	}
}