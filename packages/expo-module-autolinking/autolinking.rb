require 'json'
require 'pathname'

def use_expo_modules!(custom_options = {})
  # `self` points to Pod::Podfile object
  # `current_target_definition` is the target that is currently being visited by CocoaPods
  Autolinking.new(self, current_target_definition).useExpoModules!(custom_options)
end

# Implement stuff in the class, so we can make some helpers private and don't expose them outside.
class Autolinking
  def initialize(podfile, target)
    @podfile = podfile
    @target = target
  end

  def useExpoModules!(options = {})
    modules = findModules(options)

    if modules.nil?
      return
    end

    flags = options.fetch(:flags, {})
    projectDirectory = Pod::Config.instance.project_root

    modules.each { |expoModule|
      moduleName = expoModule['name']
      podName = expoModule['podName']
      podPath = expoModule['path']

      if hasDependency?(podName)
        # Skip if this module's pod is already declared
        next
      end

      # Install the pod.
      @podfile.pod podName, {
        :path => Pathname.new(podPath).relative_path_from(projectDirectory).to_path
      }.merge(flags)
    }
  end

  private

  def findModules(options)
    args = convertFindOptionsToArgs(options)
    json = []

    IO.popen(args) do |data|
      while line = data.gets
        json << line
      end
    end

    begin
      JSON.parse(json.join())
    rescue => error
      puts "Couldn't parse JSON coming from `expo-module-autolinking` command: #{error}"
    end
  end

  def convertFindOptionsToArgs(options)
    searchPaths = options.fetch(:searchPaths, options.fetch(:modules_paths, nil))
    ignorePaths = options.fetch(:ignorePaths, nil)
    exclude = options.fetch(:exclude, [])

    args = [
      'npx',
      'expo-module-autolinking',
      'find',
      '--platform',
      'ios',
      '--json'
    ]

    if !searchPaths.nil?
      args.concat(searchPaths)
    end

    if !ignorePaths.nil?
      args.concat(['--ignore-paths'], ignorePaths)
    end

    if !exclude.nil?
      args.concat(['--exclude'], exclude)
    end

    args
  end

  def hasDependency?(podName)
    return @target.dependencies.any? { |d| d.name == podName }
  end
end
