#!/usr/bin/ruby
require "yaml"
require "cgi"
require "erb"

def search_compounds_in_pathway(input_compounds, conf)
	# pc_hash[pathway] = [coumpound1, coumpound2, coumpound3 ...]
	pr_hash = open('../data/link_pathway_reaction.yaml', 'r') { |f| YAML.load(f) }
	pm_hash = open('../data/link_pathway_module.yaml', 'r') { |f| YAML.load(f) }
	pc_hash = open('../data/link_pathway_compound.yaml', 'r') { |f| YAML.load(f) }
	rc_hash = open('../data/link_reaction_compound.yaml', 'r') { |f| YAML.load(f) }
	mc_hash = open('../data/link_module_compound.yaml', 'r') { |f| YAML.load(f) }

	# pathway value
	pv_hash = Hash.new(0)

	# pathway's compounds & input_compounds
	pc_hash2 = Hash.new([])
	pr_hash2 = Hash.new([])
	pm_hash2 = Hash.new([])

	pc_hash.each do |p,cs|
		cs.each do |c|
			pv_hash[p] += conf["pval"] if input_compounds.index(c)
		end

		if pr_hash[p]
			pr_hash[p].each do |r|
				# input_compounds.index(rc_hash[r])
				if rc_hash[r] & input_compounds == rc_hash[r]
					pv_hash[p] += conf["rval"]
					pr_hash2[p].push(r)
				end
			end
		end

		if pm_hash[p]
			pm_hash[p].each do |m|
				if mc_hash[m] & input_compounds == mc_hash[m]
					pv_hash[p] += conf["mval"]
					pm_hash2[p].push(m)
				end
			end
		end

		pc_hash2[p] = pc_hash[p] & input_compounds
	end

	h = pv_hash.sort {|(k1, v1), (k2, v2)| v2 <=> v1 }
	return [h, pc_hash2, pr_hash2, pm_hash2]
end

def main()
	conv_compound_name
	h = search_compounds_in_pathway(compounds)
end

def modify_arr_header(arr)
	arr.map! { |item|
		if item[0..3] != "cpd:"
			"cpd:#{item}"
		else
			"#{item}"
		end
	}
	return arr
end

def add_color(compounds_list)
end

def file_to_hash(filename)
	h = Hash.new()
	File.open(filename).each do |line|
		arr = line.chomp.split("\t")
		h[arr[0]] = arr[1]
	end
	h
end

def make_url(pc_hash2, pr_hash2, pm_hash2)
	h = Hash.new()
	pc_hash2.each do |p,cs|
		pname = p.split("path:")[1]
		cs_join = cs.join("+")
		pr_join = pr_hash2[p].join("+")
		pm_join = pm_hash2[p].join("+")
		h[p] = "http://www.genome.jp/kegg-bin/show_pathway?#{pname}"
		h[p] += "+#{cs_join}" if cs_join.length > 0
		h[p] += "+#{pr_join}" if pr_join.length > 0
		h[p] += "+#{pm_join}" if pm_join.length > 0
	end
	h
end

# main
cgi = CGI.new
params = cgi.params

# 例外処理
if params["inp"][0] == "" || params["inp"].empty?
	print cgi.header({"status" => "REDIRECT", "Location" => "/"})
end

# 入力
if params["inp"][0].index(/\r\n|\r|\n/)
	compounds_list = params["inp"][0].split(/\r\n|\r|\n/)
else
	compounds_list = [params["inp"][0]]
end

# 設定
p_hash = file_to_hash("../data/list_pathway.tsv")
conf = Hash.new()
conf["rval"] = params["reac_val"][0].to_f
conf["mval"] = params["modu_val"][0].to_f
conf["pval"] = 1 # default(基準値)

# main
compounds_list = modify_arr_header(compounds_list)
pv_hash, pc_hash2, pr_hash2, pm_hash2 = search_compounds_in_pathway(compounds_list, conf)

# 細かい処理
purl_hash = make_url(pc_hash2, pr_hash2, pm_hash2)

# print
f = File.open("./index.erb").read
print cgi.header
print ERB.new(f).result(binding)
