import core.runtime;
import std;
import core.stdc.stdlib : exit;

private enum MODULE_STR = "module ";

private void printHelp() {
	writefln("Usage: module-checker <dub-root-project-dir>");
}

private void printNotInDub() {
	writeln("Run this program in a dub project");
}

private void printRootNotExists(string root) {
	writeln(root, " is not a valid dir");
}

private string moduleLineOfFile(string path) {
	auto file = File(path, "r");
	while (!file.eof) {
		immutable line = strip(file.readln());
		immutable splittedLine = line.split();
		if (splittedLine.length == 0)
			continue;
		if (splittedLine[0] == "module") {
			file.close();
			return line;
		}
	}
	file.close();
	return "null";
}

private string pathToModule(string path) {
	auto str = path.buildNormalizedPath();
	str = replace(str, dirSeparator[0], '.');
	str = stripExtension(str);
	return str;
}

private string treatPackageFile(string moduleName, out bool isPackage) {
	auto splittedModule = split(moduleName, '.');
	isPackage = splittedModule[$ - 1] == "package";
	if (isPackage) {
		return join(splittedModule[0 .. $ - 1], ".");
	} else {
		return moduleName;
	}
}

private string rawModuleToModuleString(string rawModule) {
	return MODULE_STR ~ rawModule ~ ';';
}

private void warn(string warning) {
	writeln("Note: ", warning);
}

private void problem(string problem) {
	writeln("Error: ", problem);
}

void main() {
	if (Runtime.args.length < 2) {
		printHelp();
		exit(1);
	}

	immutable inDubProj = exists("dub.sdl") || exists("dub.json");

	if (!inDubProj) {
		printNotInDub();
		exit(1);
	}

	string root = Runtime.args[1];

	if (!exists(root)) {
		printRootNotExists(root);
		exit(1);
	}

	string sourceDir = "/source/";

	string sourcePath = root ~ sourceDir;

	chdir(sourcePath);
	auto dirs = dirEntries("./", SpanMode.breadth);

	int problemCounter = 0;
	foreach (string entry; dirs) {
		if (entry.isDir())
			continue;

		string moduleLine = moduleLineOfFile(entry);

		if (!startsWith(moduleLine, "module")) {
			immutable path = entry.buildNormalizedPath();
			warn("No module declaration in " ~ path ~ " (may be ok)");
			continue;
		}
		bool isPackage;
		immutable finalModuleStr = rawModuleToModuleString(
				treatPackageFile(pathToModule(entry), isPackage));

		if (finalModuleStr != moduleLine) {
			immutable path = entry.buildNormalizedPath();
			if (isPackage && count(path, dirSeparator) == 0) {
				warn("Toplevel package.d (weird ?)");
				continue;
			}
			problemCounter++;
			problem("Problem detected at " ~ path ~ " :\n\tModule declaration should be \""
					~ finalModuleStr ~ "\" instead of \"" ~ moduleLine ~ "\"");
		}
	}

	writeln("Work done with ", problemCounter, problemCounter > 1 ? " problems" : " problem");
}
