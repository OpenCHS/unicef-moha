# <makefile>
# Objects: refdata, package
# Actions: clean, build, deploy
help:
	@IFS=$$'\n' ; \
	help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//'`); \
	for help_line in $${help_lines[@]}; do \
	    IFS=$$'#' ; \
	    help_split=($$help_line) ; \
	    help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
	    help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
	    printf "%-30s %s\n" $$help_command $$help_info ; \
	done
# </makefile>

port:= $(if $(port),$(port),8021)
server:= $(if $(server),$(server),http://localhost)
server_url:=$(server):$(port)

su:=$(shell id -un)
org_name=UNICEF - MOHA

define _curl
	curl -X $(1) $(server_url)/$(2) -d $(3)  \
		-H "Content-Type: application/json"  \
		-H "ORGANISATION-NAME: $(org_name)"  \
		$(if $(token),-H "AUTH-TOKEN: $(token)",)
	@echo
	@echo
endef

auth:
	$(if $(poolId),$(eval token:=$(shell node scripts/token.js $(poolId) $(clientId) $(username) $(password))))
	echo $(token)

# <create_org>
create_org: ## Create MDSR org and user+privileges
	psql -U$(su) openchs < create_organisation.sql
# </create_org>

# <refdata>
deploy_concepts:
	$(call _curl,POST,concepts,@concepts.json)
	$(call _curl,POST,concepts,@cbmdr/CommunityBasedVerbalAutopsyFormConcept.json)

deploy_subjects:
	$(call _curl,POST,operationalSubjectTypes,@operationalModules/operationalSubjectTypes.json)

deploy_refdata: deploy_subjects deploy_concepts
	$(call _curl,POST,catchments,@catchments.json)
	$(call _curl,POST,facilities,@test-facilities.json)
	$(call _curl,POST,users,@test-users.json)
	$(call _curl,POST,programs,@programs.json)
	$(call _curl,POST,encounterTypes,@encounterTypes.json)
	$(call _curl,POST,operationalEncounterTypes,@operationalModules/operationalEncounterTypes.json)
	$(call _curl,POST,operationalPrograms,@operationalModules/operationalPrograms.json)

	$(call _curl,POST,forms,@fbmdr/FacilityBasedMaternalDeathReviewForm.json)
	$(call _curl,POST,forms,@cbmdr/CommunityBasedVerbalAutopsy.json)
	$(call _curl,POST,forms,@MaternalDeathCaseSummaryForm.json)
	$(call _curl,POST,forms,@MaternalDeathNotificationForm.json)

	$(call _curl,POST,formMappings,@formMappings.json)

# </refdata>

# <deploy>
deploy: deploy_refdata deploy_rules 

deploy_rules:
	node index.js "$(server_url)" "$(token)"

deploy_staging:
	make auth deploy poolId=ap-south-1_tuRfLFpm1 clientId=93kp4dj29cfgnoerdg33iev0v server=https://staging.openchs.org port=443 username=admin password=$(STAGING_ADMIN_USER_PASSWORD)

create_deploy: create_org deploy ##
# </c_d>

deps:
	npm i

# <package>
#build_package: ## Builds a deployable package
#	rm -rf output/impl
#	mkdir -p output/impl
#	cp registrationForm.json catchments.json deploy.sh output/impl
#	cd output/impl && tar zcvf ../openchs_impl.tar.gz *.*
# </package>
