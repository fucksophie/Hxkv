package hxkv;

import haxe.Json;

class Filesystem {
    public function new() {
        
    }
    public function write(file: String, data: String) {

    }
    public function read(file: String): String {
        return "unimplemented";
    }
    public function delete(file: String) {

    }
}

#if sys
class SysFilesystem extends Filesystem {
    public override function new() {
        super();
    }
    public override function write(file: String, data: String) {
        var fl = sys.io.File.write(file);
        fl.writeString(data);
        fl.close();
    }
    public override function read(file: String): String {
        var bytes = sys.io.File.read(file).readAll();
        return bytes.getString(0, bytes.length);
    }
    public override function delete(file: String) {
        sys.FileSystem.deleteFile(file);
    }
}
#else
#if js
class JsFilesystem extends Filesystem {
    public override function new() {
        super();
    }
    public override function write(file: String, data: String) {
        var localStorageFound = false;
        js.Syntax.code("if(globalThis.localStorage)localStorageFound=true;");
        if(localStorageFound) {
            js.Browser.getLocalStorage().setItem(file, data);
        } else {
            // this wrangles it's way through weird bullshit to make Bun/Deno/Node compatability
            // Deno/Browsers support localStorage first though, so that'll be picked
            js.Syntax.code('globalThis.Deno?Deno.writeTextFileSync(file,data):globalThis.Bun?Bun.write(file,data):globalThis.require&&require("fs").writeFileSync(file,data);');
        }
    }

    public override function read(file: String): String {
        var localStorageFound = false;
        var data = "";
        js.Syntax.code("if(globalThis.localStorage)localStorageFound=true;");
        if(localStorageFound) {
            data = js.Browser.getLocalStorage().getItem(file);
        } else {
            // this wrangles it's way through weird bullshit to make Bun/Deno/Node compatability
            // all of these apart from Node support localStorage first though, so that'll be picked
            js.Syntax.code('data=globalThis.Deno?Deno.readTextFileSync(file):require?require("fs").readFileSync(file):"unsupported platform";');
        }
        return data;
    }
    public override function delete(file: String) {
        var localStorageFound = false;
        js.Syntax.code("if(globalThis.localStorage)localStorageFound=true;");
        if(localStorageFound) {
            js.Browser.getLocalStorage().removeItem(file);
        } else {
            // this is a kniff related to it - 
            // bun's BunFile does not support deleting
            // so we just remove the whole bun loop and it'll just use fs.unlink indead
            js.Syntax.code('globalThis.Deno?Deno.removeSync(file):globalThis.require&&require("fs").unlink(file);');
        }
    }
}
#end
#if flash
class FlashFilesystem extends Filesystem {
    public function new() {
        super();
    }

    public override function write(file: String, data: String) {
        var so = flash.net.SharedObject.getLocal(file);
        so.data.filedata = data;
        so.flush();
    }
    public override function read(file: String): String {
        var so = flash.net.SharedObject.getLocal(file);
        trace(so.data);
        return so.data.filedata;
    }
    public override function delete(file: String) {
        var so = flash.net.SharedObject.getLocal(file);
        so.clear();
    }
}
#end
#end

class Hxkv {
    private var name: String;
    private var fs: Filesystem;
    private var data: Map<String, Dynamic> = new Map();

    public function new(name: String) {
        this.name = name;
        #if sys
        this.fs = new SysFilesystem();
        #else
        #if js
        this.fs = new JsFilesystem();
        #end
        #if flash
        this.fs = new FlashFilesystem(); 
        #end
        #end
        
        var raw: String;

        try {
            raw = this.fs.read(this.name+".json");
            if(raw.length == 0) {
                raw = '{"h":{}}';
            }
        } catch(e) {
            this.fs.write(this.name+".json", '{"h":{}}');
            raw = '{"h":{}}';
        }

        var json = Json.parse(raw);
        if(Reflect.field(json, "h") != null) {
            json = json.h;
        }
        for(n in Reflect.fields(json)) {
            trace(n, Reflect.field(json, n));
            data.set(n, Reflect.field(json, n));
        }

        trace(data, json);
    }

    public function set(key: String, value: Dynamic): Void {
        data.set(key, value);
        trace(data);

    }

    public function get(key: String): Dynamic {
        return data.get(key);
    }
    
    public function flush() {
        trace(data);
        this.fs.write(this.name+".json", Json.stringify(data));
    }
}