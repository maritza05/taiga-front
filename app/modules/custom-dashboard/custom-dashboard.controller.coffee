###
# Copyright (C) 2014-2016 Taiga Agile LLC <taiga@taiga.io>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: projects-listing.controller.coffee
###
taiga = @.taiga

groupBy = @.taiga.groupBy

class CustomDashboardController
    # @.$inject = [
    #     "tgCurrentUserService",
    #     "tgProjectsService",
    # ]
    #
    # constructor: (@currentUserService, @projectsService) ->
    #     taiga.defineImmutableProperty(@, "projects", () => @projectsService.getAllProjects())
    #
    # newProject: ->
    #     @projectsService.newProject()
    @.$inject = [
        "$scope"
        "tgCurrentUserService",
        "tgProjectsService",
        "$tgResources",
        "tgErrorHandlingService",
        "$tgRepo",

    ]

    milestonesOrder: {}

    constructor: (@scope, @currentUserService, @projectsService, @rs, @errorHandlingService, @repo) ->
        @.loadMainProjects()
        taiga.defineImmutableProperty(@, "allprojects", () => @scope.projectsTry)
        @scope.data = @allprojects
        console.log("The is the actual scope data:")
        console.log(@currentUserService.projects.get('all'))

    loadMainProjects: () ->
          return @rs.projects.list('all').then (result) =>
            open_projects = _.filter(result, ((project) -> project.is_private == false))
            console.log("The open projects")
            console.log(result)
            @scope.projectsTry = Immutable.fromJS(open_projects)
          return projectsTry

    loadUserstories: (projectId) ->
          return @rs.projects.get(projectId).then (result) =>
            @scope.testProject = result
          return result

    loadIssues: (projectId) ->
          return @rs.issues.list(projectId).then (result) =>
            @scope.issues = result.models
          return result


    loadProjectStats: (projectId) ->
         return @rs.projects.stats(projectId).then (stats) =>
           @scope.stats = stats
           totalPoints = if stats.total_points then stats.total_points else stats.defined_points
           if totalPoints
               @scope.stats.completedPercentage = Math.round(100 * stats.closed_points / totalPoints)
           else
               @scope.stats.completedPercentage = 0
           @scope.showGraphPlaceholder = !(stats.total_points? && stats.total_milestones?)
           return stats

    setMilestonesOrder: (sprints) ->
        for sprint in sprints
          @.milestonesOrder[sprint.id] = {}
          for it in sprint.user_stories
            @.milestonesOrder[sprint.id][it.id] = it.sprint_order

    loadSprints: (projectId)->
        return @rs.sprints.list(projectId).then (result) =>
          sprints = result.milestones
          @.setMilestonesOrder(sprints)

          @scope.totalMilestones = sprints
          @scope.totalClosedMilestones = result.closed
          @scope.totalOpenMilestones = result.open
          @scope.totalMilestones = @scope.totalOpenMilestones + @scope.totalClosedMilestones

          for sprint in sprints
              sprint.user_stories = _.sortBy(sprint.user_stories, "sprint_order")
              closed_points = 0
              if sprint.closed_points
                 closed_points = sprint.closed_points
              console.log("Sprint name: " + sprint.name)
              sprint.completedPercentagePoints = Math.round(100*sprint.closed_points/sprint.total_points)
              console.log("Completed percentage: " + sprint.completedPercentagePoints)

          @scope.sprints = sprints
          @scope.closedSprints = [] if !@scope.closedSprints

          @scope.sprintsCounter = sprints.length
          @scope.sprintsById = groupBy(sprints, (x) -> x.id)
          @scope.currentSprint = @.findCurrentSprint()
          @scope.plannedSpeed = 0
          @scope.actualSpeed = 0
          sprintsTotalPoints = _.map(sprints, (ml) -> ml.total_points)
          sumSprintsTotalPoints = _.reduce(sprintsTotalPoints, ((res, n) -> res + n), 0)
          sprintsClosedPoints = _.map(sprints, (ml) -> ml.closed_points)
          sumSprintsClosedPoints = _.reduce(sprintsClosedPoints, ((res, n) -> res + n), 0)
          if sprints.length > 0
              @scope.plannedSpeed = Math.round(sumSprintsTotalPoints / sprints.length)
              @scope.actualSpeed = Math.round(sumSprintsClosedPoints / sprints.length)
          return sprints

    loadMembersStats: (members) ->
        for member in members
            sprintMember = []
            for sprint in @scope.sprints
                userstories_m = _.filter(sprint.user_stories, ((story) -> story.assigned_to == member.id))
                completed_u = 0
                commited_u = 0
                for userstory in userstories_m
                    totalpoints = userstory.total_points
                    commited_u += totalpoints
                    if userstory.is_closed
                        completed_u += totalpoints

                sprintMember.push({'name': sprint.name, 'completed': completed_u, 'commited': commited_u})
            totalCommitedPoints = 0
            totalCompletedPoints = 0
            for sprint in sprintMember
                totalCompletedPoints += sprint.completed
                totalCommitedPoints += sprint.commited
            console.log("Complited points of member: " + member.full_name)
            console.log(totalCompletedPoints)
            console.log("Commited points")
            console.log(totalCommitedPoints)
            console.log("---------------------")
            if totalCommitedPoints
                member.completedPercentageMember = Math.round(100*totalCompletedPoints/totalCommitedPoints)
            else
                member.completedPercentageMember = 0


    loadSprintStats: (projectId, sprintId) ->
        return @rs.sprints.stats(projectId, sprintId).then (stats) =>
          totalPointsSum = _.reduce(_.values(stats.total_points), ((res, n) -> res + n), 0)
          completedPointsSum = _.reduce(_.values(stats.completed_points), ((res, n) -> res + n), 0)
          remainingPointsSum = totalPointsSum - completedPointsSum
          remainingTasks = stats.total_tasks - stats.completed_tasks
          @scope.sprintStats = stats
          @scope.sprintStats.totalPointsSum = totalPointsSum
          @scope.sprintStats.completedPointsSum = completedPointsSum
          @scope.sprintStats.remainingPointsSum = remainingPointsSum
          @scope.sprintStats.remainingTasks = remainingTasks
          if stats.total_userstories
              @scope.sprintStats.completedPercentageUserstories = Math.round(100*stats.completed_userstories/stats.total_userstories)
          else
              @scope.sprintStats.completedPercentageUserstories = 0

          if stats.totalPointsSum
              @scope.sprintStats.completedPercentage = Math.round(100*@scope.sprintStats.completedPointsSum/@scope.sprintStats.totalPointsSum)
          else
              @scope.sprintStats.completedPercentage = 0

          return stats

    findCurrentSprint: () ->
      currentDate = new Date().getTime()

      return _.find @scope.sprints, (sprint) ->
          start = moment(sprint.estimated_start, 'YYYY-MM-DD').format('x')
          end = moment(sprint.estimated_finish, 'YYYY-MM-DD').format('x')
          return currentDate >= start && currentDate <= end

    showReport: ->
        console.log("Id: " + @scope.projectId)
        # console.log("Project Stats:")
        # console.log(JSON.stringify(@scope.stats, null, 4))
        console.log("Sprints:")
        console.log(JSON.stringify(@scope.sprints, null, 4))

    loadInitialData: (projectId) ->
        return @.loadProjectStats(projectId)
            .then(=> @.loadSprints(projectId))
            .then(=> @.loadUserstories(projectId))
            .then(=> @.loadIssues(projectId))


    saveUserstory: (userstory) ->
        return @repo.save(userstory)


    setProject: (project) ->
        if @scope.sprintStats?
            @scope.sprintStats = undefined
        if @scope.actualSprint?
            @scope.actualSprint = undefined
        if @scope.member?
            @scope.member = undefined
        @scope.project = project
        @scope.projectId = project.id
        @scope.slider = {
            value: 10
            options:
                floor: 0
                ceil: 100
                ticksArray: [0, 10, 25, 50, 60, 70, 80, 100]
        }
        promise = @.loadInitialData(@scope.projectId)
        promise.then =>
            console.log('The entire project')
            console.log(@scope.sprints)
            @scope.userstories_status = @scope.testProject.us_statuses
            @scope.members = _.filter(@scope.testProject.members, ((user) -> user.is_active == true))
            @scope.roles = @scope.testProject.roles
            @.loadMembersStats(@scope.members)
            console.log(@scope.members)
            console.log(@scope.issues)



    setMember: (member) ->
        @scope.member = member
        sprintMember = []
        console.log("-----This are the sprints")
        for sprint in @scope.sprints
            userstories_m = _.filter(sprint.user_stories, ((story) -> story.assigned_to == member.id))
            console.log("****** USERSTORIES ASSIGNED TO THE USER")
            console.log(userstories_m)
            completed_u = 0
            commited_u = 0
            for userstory in userstories_m
                totalpoints = userstory.total_points
                commited_u += totalpoints
                if userstory.is_closed
                    completed_u += totalpoints
            sprintMember.push({ "name" : sprint.name, "commited": commited_u, "completed": completed_u})
            console.log("******** SPRINT MEMBER")
            console.log(sprintMember)
        @scope.completed_points_member = sprintMember

        totalCommitedPoints = 0
        totalCompletedPoints = 0
        for sprint in @scope.completed_points_member
            totalCompletedPoints += sprint.completed
            totalCommitedPoints += sprint.commited
        @scope.completedPercentageMember = Math.round(100*totalCompletedPoints/totalCommitedPoints)


    setSprint: (sprint) ->
        @scope.actualSprint = sprint
        promise = @.loadSprintStats(@scope.projectId, sprint.id)
        promise.then =>
            console.log("Sprint stats: ")
            console.log(@scope.sprintStats)

    isProject: (project) ->
        return @scope.project == project


angular.module("taigaCustomDashboard").controller("CustomDashboard", CustomDashboardController)



#############################################################################
## Burndown graph directive
#############################################################################
BurndownGraphDirective = ->
    redrawChart = (element, dataToDraw) ->
        milestonesRange = [0..(dataToDraw.milestones.length - 1)]
        milestonesNames = _.map(dataToDraw.milestones, (ml) -> ml.name)
        optimal_line = _.map(dataToDraw.milestones, (ml) -> ml.optimal)
        evolution_line = _.filter(_.map(dataToDraw.milestones, (ml) -> ml.evolution), (evolution) -> evolution? )
        client_increment_line = _.map(dataToDraw.milestones, (ml) -> ml["client-increment"])

        options = {
            chart:
                type: 'area'
            title:
                text: ''
            xAxis:
                categories: milestonesRange
                title:
                    text: 'Sprints'
            yAxis:
                min: 0
                title: {
                    text: 'Puntos (Historias de Usuario)'
                }
                labels: {
                    formatter: () ->
                        return this.value
                }
            tooltip: {
                formatter:  () ->
                    return '<b>' +  this.series.name + '</b><br/><b>Sprint: </b>' + this.x + '<br/><b>Points: </b>' + Math.round(this.y)
            }
            plotOptions:
                area:
                    fillOpactiy: 0.2
            credits: {
                enabled: false
            }
            series: [
                {
                    name: 'Óptimo'
                    color: '#DDDDDD'
                    data: optimal_line
                    marker:
                        fillColor: '#DDDDDD'
                        lineWidth: 3
                        lineColor: '#DDDDDD'
                }
                {
                    name: 'Real'
                    data: evolution_line
                    marker:
                        fillColor: 'rgba(54,184,213, 0.7)'
                        lineWidth: 3
                        lineColor: '38B8D5'
                }
            ]
        }
        element.empty()
        Highcharts.chart('main-burndown-chart', options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "stats", (value) ->
            if $scope.stats?
                redrawChart(element, $scope.stats)

            $scope.$on "resize", ->
                redrawChart(element, $scope.stats)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}

angular.module("taigaCustomDashboard").directive("tgBurndownDirective", [BurndownGraphDirective])


#############################################################################
## Completed Project Percentage directive
#############################################################################
ProjectPercentDirective = ->
    link = ($scope, $el, $attrs) ->
            element = angular.element($el)
            step = element.find('.pie-value')
            $scope.$watch "stats", (oldValue, newValue) ->
                $(element).easyPieChart({
                    barColor: '#fff'
                    scaleColor: false
                    trackColor: '#68B828'
                    lineCap: 'butt'
                    lineWidth: 10
                    animate: 1000
                    onStep: (value) -> step.text(value + '%')
                    onStop: (value, to) -> step.text(to + '%')
                }).data('easyPieChart').update($scope.stats.completedPercentage)
      return {link: link}
angular.module("taigaCustomDashboard").directive("tgProjectPercentDirective", [ProjectPercentDirective])

#############################################################################
## Project Deviation directive
#############################################################################
ProjectDeviationDirective = ->
    redrawChart = (element, dataToDraw) ->
        sprintsClosedPoints = _.map(dataToDraw, (ml) -> ml.closed_points)
        for point, i in sprintsClosedPoints
            sprintsClosedPoints[i] = 0 if point == null

        sumClosedPoints = _.reduce(sprintsClosedPoints, ((initial, num) -> initial + num), 0)
        avgClosedPoints = 0
        if sprintsClosedPoints.length != 0
            avgClosedPoints = sumClosedPoints / sprintsClosedPoints.length

        sprintsTotalPoints = _.map(dataToDraw, (ml) -> ml.total_points)
        sumTotalPoints = _.reduce(sprintsTotalPoints, ((initial, num) -> initial + num), 0)
        avgTotalPoints = 0
        if sprintsTotalPoints.length != 0
            avgTotalPoints = sumTotalPoints / sprintsTotalPoints.length

        deviation = 0
        if avgTotalPoints != 0
            deviation = 100 * (Math.abs(avgClosedPoints - avgTotalPoints)) / avgTotalPoints
            deviation = Math.round(deviation)

        step = element.find('.pie-value')
        $(element).easyPieChart({
              barColor: '#fff'
              scaleColor: false
              trackColor: '#26A69A'
              lineCap: 'butt'
              lineWidth: 10
              animate: 1000
              onStep: (value) -> step.text(value + '%')
              onStop: (value, to) -> step.text(to + '%')
          }).data('easyPieChart').update(deviation)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "sprints", (value) ->
            if $scope.sprints?
                redrawChart(element, $scope.sprints)

            $scope.$on "resize", ->
                redrawChart(element, $scope.sprints)

        $scope.$on "destroy", ->
            $el.off()
    return {link: link}
angular.module("taigaCustomDashboard").directive("tgProjectDeviationDirective", [ProjectDeviationDirective])

#############################################################################
## Project Solved Issues directive
#############################################################################
ProjectCompletedIssuesDirective = ->
    link = ($scope, $el, $attrs) ->
            element = angular.element($el)
            step = element.find('.pie-value')

            $scope.$watch "issues", (oldValue, newValue) ->
                num_closed_issues = 0
                for issue in $scope.issues
                  if issue.is_closed
                    num_closed_issues += 1

                avg_closed_issues = 0
                if $scope.issues.length
                    avg_closed_issues = Math.round((num_closed_issues * 100) / $scope.issues.length)

                $(element).easyPieChart({
                      barColor: '#fff'
                      scaleColor: false
                      trackColor: '#914887'
                      lineCap: 'butt'
                      lineWidth: 8
                      onStep: (value) -> step.text(value + '%')
                      onStop: (value, to) -> step.text(to + '%')
                  }).data('easyPieChart').update(avg_closed_issues)
      return {link: link}
angular.module("taigaCustomDashboard").directive("tgProjectCompletedIssuesDirective", [ProjectCompletedIssuesDirective])

#############################################################################
## Assigned Points by Role
#############################################################################
AssignedPointsByRoleDirective = ->
    redrawChart = (element, stats, roles) ->
        assignedPointsByRole = stats.assigned_points_per_role
        totalPoints = 0
        for key of assignedPointsByRole
            totalPoints += assignedPointsByRole[key]
        pointsPerRole = []
        console.log(assignedPointsByRole)
        for role in roles
            id = role.id
            for key of assignedPointsByRole
                if parseInt(key) is parseInt(id)
                    percent = (assignedPointsByRole[key] * 100) / totalPoints
                    pointsPerRole.push({'name': role.name, 'y': percent})

        options =
            chart:
                plotBackgroundColor: null
                plotBorderWidth: null
                plotShadow: false
                backgroundColor:'transparent'
                type: 'pie'
            title:
                text: ''
            exporting:
                enabled: false
            credits: {
                enabled: false
            }
            tooltip:
                pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
            plotOptions:
                pie:
                    allowPointSelect: true
                    cursor: 'pointer'
                    dataLabels:
                      enabled: false
                    showInLegend: false
            series: [
                {
                    name: 'Points'
                    colorByPoint: true
                    data: pointsPerRole
                  }
                ]

        element.empty()
        Highcharts.chart('points-role', options)


    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watchGroup ["stats", "roles"], (oldValue, newValue) ->
            if $scope.stats?
                redrawChart(element, $scope.stats, $scope.roles)

        $scope.$on "resize", ->
            redrawChart(element, $scope.stats, $scope.roles)

        $scope.$on "destroy", ->
            $el.off()
    return {link: link}
angular.module('taigaCustomDashboard').directive("tgAssignedPointsByRoleGraph", [AssignedPointsByRoleDirective])

#############################################################################
## Eficciency in Estimation directive
#############################################################################
EffiencyEstimationDirective = ->
    redrawChart = (element, dataToDraw) ->
        user_stories_by_sprint = []
        for sprint in dataToDraw
            user_stories_by_sprint.push(sprint.user_stories)

        user_stories = []
        for stories in user_stories_by_sprint
            for us in stories
                user_stories.push(us)

        points = _.map(user_stories, (us) -> us.total_points)
        real_points = _.map(user_stories, (us) -> us.real_total_points)

        total_points = _.reduce(points, ((initial, num) -> initial + num), 0)
        real_total_points = _.reduce(real_points, ((initial, num) -> initial + num), 0)

        percentage = 0
        if total_points != 0
            percentage = Math.round((real_total_points * 100) / total_points)

        console.log('*** This are the userstories')
        console.log(user_stories)

        console.log('*** This are the total points')
        console.log(total_points)

        console.log('*** This are the real points')
        console.log(real_total_points)

        console.log('*** This is the percentage')
        console.log(percentage)


        step = element.find('.pie-value')
        $(element).easyPieChart({
              barColor: '#fff'
              scaleColor: false
              trackColor: '#26A69A'
              lineCap: 'butt'
              lineWidth: 10
              animate: 1000
              onStep: (value) -> step.text(value + '%')
              onStop: (value, to) -> step.text(to + '%')
          }).data('easyPieChart').update(percentage)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "sprints", (value) ->
            if $scope.sprints?
                redrawChart(element, $scope.sprints)

            $scope.$on "resize", ->
                redrawChart(element, $scope.sprints)

        $scope.$on "destroy", ->
            $el.off()
    return {link: link}
angular.module("taigaCustomDashboard").directive("tgEfficiencyEstimationDirective", [EffiencyEstimationDirective])


#############################################################################
## CustomBurndownHighchart graph directive
#############################################################################
PredictiveBurndownDirective = ->

    redrawChart = (element,dataToDraw) ->
        milestonesRange = [0..(dataToDraw.milestones.length - 1)]
        milestonesNames = _.map(dataToDraw.milestones, (ml) -> ml.name)
        milestonesRange[0] = 'Backlog'

        closed_points = _.filter(_.map(dataToDraw.milestones, (ml) -> ml.evolution), (evolution) -> evolution? )
        client_increment_line = _.map(dataToDraw.milestones, (ml) -> ml["client-increment"])
        evolution = []
        for point, i in closed_points
            if i > 0
                change = (closed_points[i-1] - point) * -1
            else
                change = 0
            evolution.push(change)

        options = {
          chart:
              type: 'column'

          title:
              text: ''

          xAxis:
              categories: milestonesRange
              title:
                  text: 'Sprints'

          yAxis: {
              tickInterval: 200
              title:
                  text: 'Puntos (Historias de Usuario)'
              stackLabels:
                  enabled: true
                  style:
                      color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'
          }
          legend:
              backgroundColor: (Highcharts.theme && Highcharts.theme.background2) || 'white'
              shadow: false

          tooltip: {
              headerFormat: '<b>{point.x}</b><br/>'
              pointFormat: '{series.name}: {point.y}<br/>Total: {point.stackTotal}'
          }
          plotOptions: {
              column:
                  stacking: 'normal',
                  dataLabels:
                      enabled: true,
                      color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white'
          }
          credits:
              enabled: false
          series: [
              {
                  name: 'Completado'
                  data: evolution
                  color: '#E3ECC8'
              }
              {
                  name: 'Pendiente'
                  data: closed_points
                  color: '#90EE90'
              }
              {
                 name: 'Añadido'
                 data: client_increment_line
                 color: '#577CA0'
              }
          ]
        }

        element.empty()
        Highcharts.chart('predictive-burndown-chart', options)

        # chart.setOption(options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "stats", (oldValue, newValue) ->
            if $scope.stats?
                redrawChart(element, $scope.stats)

        $scope.$on "resize", ->
            redrawChart(element, $scope.stats)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgPredictiveBurndownDirective", [PredictiveBurndownDirective])

###########################################################################
## Prediction Burndown Chart
###########################################################################
SprintsPredictionDirective = ->
    redrawChart = (element,dataToDraw) ->
        milestonesRange = [0..(dataToDraw.milestones.length - 1)]
        milestonesNames = _.map(dataToDraw.milestones, (ml) -> ml.name)
        closedPoints = _.filter(_.map(dataToDraw.milestones, (ml) -> ml.evolution), (evolution) -> evolution? )
        validSprints = _.filter(dataToDraw.milestones, (ml) -> ml.name not in ['Future sprint', 'Project End'])

        evolution = []
        for sprint, i in validSprints
            if i > 0
                change = validSprints[i-1].evolution - sprint.evolution
            else
                change = 0
            evolution.push(change)

        # we can calculate the speed with at least three valid sprints

        avgSpeed = 0
        message = element.find('.prediction')
        if evolution.length >= 3
            sumClosed = _.reduce(evolution, ((res, n) -> res + n), 0)
            avgSpeed = Math.round(sumClosed / evolution.length)

            lastRemainingWork = closedPoints[closedPoints.length - 1]

            if avgSpeed > 0
                neededSprints = Math.round(lastRemainingWork / avgSpeed)
                console.log("lastRemainingWork: " + lastRemainingWork)
                console.log("Average speed: " + avgSpeed )
                text = "De acuerdo a la velocidad alcanzada en los últimos 3 sprints. Tomará " + neededSprints + " sprints, a partir del actual, el terminar el proyecto"
                message.text(text)
        else
            message.text("Con al menos tres sprints se pueden realizar predicciones")

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "stats", (oldValue, newValue) ->
            if $scope.stats?
                redrawChart(element, $scope.stats)

        $scope.$on "resize", ->
            redrawChart(element, $scope.stats)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgSprintsPredictionDirective", [SprintsPredictionDirective])

#############################################################################
## VelocityHighchart graph directive
#############################################################################
CustomVelocityHighchartGraphDirective = ->

    redrawChart = (element, dataToDraw) ->
        sprintsNames = _.map(dataToDraw, (ml) -> ml.name)
        sprintsNames = sprintsNames.reverse()
        sprintsClosedPoints = _.map(dataToDraw, (ml) -> ml.closed_points)
        sprintsClosedPoints = sprintsClosedPoints.reverse()
        for point, index in sprintsClosedPoints
            sprintsClosedPoints[index] = 0 if point == null

        sprintsTotalPoints = _.map(dataToDraw, (ml) -> ml.total_points)
        sprintsTotalPoints = sprintsTotalPoints.reverse()

        options = {
            chart:
                type: 'column'

            title:
                text: ''

            xAxis: {
                categories: sprintsNames
                crosshair: true
                title:
                    text: 'Sprints'
            }
            credits:
                enabled: false
            yAxis: {
                min: 0
                title:
                    text: 'Puntos (Historias de Usuario)'
            }

            tooltip: {
                headerFormat: '<span style="font-size:10px">{point.key}</span><table>'
                pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
                '<td style="padding:0"><b>{point.y:.1f} mm</b></td></tr>'
                footerFormat: '</table>'
                shared: true
                useHTML: true
            }
            plotOptions: {
                column: {
                    pointPadding: 0.2,
                    borderWidth: 0
                }
            }
            series: [
                {
                    name: 'Completado',
                    data: sprintsClosedPoints
                    color: Highcharts.getOptions().colors[0]
                }
                {
                    name: 'Planeado'
                    data:  sprintsTotalPoints
                    color: Highcharts.getOptions().colors[2]
                }

            ]
        }


        element.empty()
        Highcharts.chart('high3', options)

        # chart.setOption(options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "sprints", (value) ->

            if $scope.sprints?
                redrawChart(element, $scope.sprints)

        $scope.$on "resize", ->
            redrawChart(element, $scope.sprints)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgCustomVelocityHighchartGraph", [CustomVelocityHighchartGraphDirective])


#############################################################################
## Mean velocity gauge directive
#############################################################################
ProjectIsVelocityGauge = ->
    link = ($scope, $el, $attrs) ->
            opts =
                lines: 10
                angle: 0
                lineWidth: 0.41
                pointer:
                  length: 0.75
                  strokeWidth: 0.035
                  color: 'rgba(0, 0, 0, 0.38)'
                limitMax: true
                colorStart: '#fff'
                colorStop: '#fff'
                strokeColor: '#68B828'
                generateGradient: true
            element = angular.element($el)
            canv = element[0]

            $scope.$watch "sprints", (oldValue, newValue) ->
                plannedSpeed = 0
                actualSpeed = 0
                sprintsTotalPoints = _.map($scope.sprints, (ml) -> ml.total_points)
                sumSprintsTotalPoints = _.reduce(sprintsTotalPoints, ((res, n) -> res + n), 0)
                sprintsClosedPoints = _.map($scope.sprints, (ml) -> ml.closed_points)
                sumSprintsClosedPoints = _.reduce(sprintsClosedPoints, ((res, n) -> res + n), 0)
                if $scope.sprints.length > 0
                    plannedSpeed = Math.round(sumSprintsTotalPoints / $scope.sprints.length)
                    actualSpeed = Math.round(sumSprintsClosedPoints / $scope.sprints.length)

                gauge = new Gauge(canv).setOptions(opts)
                gauge.maxValue = plannedSpeed
                gauge.animationSpeed = 53
                gauge.set(actualSpeed)
                gauge.setTextField(actualSpeed+'%')

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgProjectIsVelocityGauge", [ProjectIsVelocityGauge])

#############################################################################
## Sprint Points Percentage directive
#############################################################################
SprintPercentDirective = ->
    link = ($scope, $el, $attrs) ->
            element = angular.element($el)
            step = element.find('.pie-value')
            console.log("Step: ")
            console.log(step)
            $scope.$watch "sprintStats", (oldValue, newValue) ->
                if $scope.sprintStats?
                    percentValue = $scope.sprintStats.completedPercentage
                else
                    percentValue = 0

                $(element).easyPieChart({
                    barColor: '#8BC34A'
                    scaleColor: false
                    trackColor: '#eee'
                    lineCap: 'round'
                    lineWidth: 8
                    animate: 1000
                    onStep: (value) -> step.text(value + '%')
                    onStop: (value, to) -> step.text(to + '%')
                }).data('easyPieChart').update(percentValue)
      return {link: link}
angular.module("taigaCustomDashboard").directive("tgSprintPercentDirective", [SprintPercentDirective])

#############################################################################
## Sprint stats directive
#############################################################################
SprintStatsDirective = ->
    redrawChart = (element, sprintStats) ->
        days = sprintStats.days
        dayName = _.map(days, (sp) -> sp.name)
        optimalPoints = _.map(days, (sp) -> Math.round(sp.optimal_points))
        actualPoints = _.map(days, (sp) -> Math.round(sp.open_points))
        dayName = _.sortBy(dayName, (day) -> day)

        options =
            chart:
                type: 'area'
            title:
                text: ''
            xAxis:
                categories: dayName
                title:
                    text: 'Días'
            yAxis:
                min: 0
                title:
                    text: 'Puntos (Historias de Usuario)'
            credits:
                enabled: false
            tooltip:
                crosshairs: true
                shared: true
                valueSuffix: ' puntos'
            plotOptions:
                area:
                    pointStart: 0
            series: [
                {
                    name: 'Actual'
                    data: actualPoints
                    marker:
                        fillColor: 'white'
                        lineWidth: 2
                        lineColor: Highcharts.getOptions().colors[0]
                }
                {
                    name: 'Planeado'
                    data: optimalPoints
                    marker:
                        fillColor: 'white'
                        lineWidth: 2
                        lineColor: '#E3ECC8'
                    color: '#E3ECC8'
                }
            ]

        Highcharts.chart('velocity-sprint', options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watchGroup ["project", "sprintStats"], (oldValues, newValues) ->
            if $scope.sprintStats?
                redrawChart(element, $scope.sprintStats)


                $scope.$on "resize", ->
                    redrawChart(element, $scope.sprintStats)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgSprintStatsGraph", [SprintStatsDirective])

#############################################################################
## Confidence in Estimations Highchart directive
#############################################################################
ConfidenceBandHighcharts = ->

    redrawChart = (element, sprint, value) ->
        ranges = []
        values = []
        calculatedValues = []
        ids = []
        names = []
        console.log("Checking the userstories")
        console.log(sprint)
        console.log("Sprint userstories")
        console.log(sprint.user_stories)
        for userstory, i in sprint.user_stories
            sumEstimatedPoints = userstory.total_points
            realPoints = Math.round(userstory.real_total_points)
            percent = Math.round((value * realPoints)/100)
            lower_percent = realPoints - percent
            upper_percent = realPoints + percent

            values.push([i, realPoints])
            ranges.push([i, lower_percent, upper_percent])
            calculatedValues.push([i, sumEstimatedPoints])
            ids.push(userstory.ref)
            names.push(userstory.subject)

        console.log("Ranges")
        console.log(ranges)

        console.log("Values")
        console.log(values)

        option = {
          chart:
              type: 'spline'
          title:
              text: ''
          credits:
              enabled: false
          xAxis:
              type: 'category'
              categories: ids
              title:
                  text: 'Historias de Usuario'
          yAxis:
              min: 0
              tickInterval: 50
              title:
                  text: 'Puntos (Historias de Usuario)'
          tooltip:
              crosshairs: true
              shared: true
              valueSuffix: ' puntos'

          series: [
            {
                name: 'Puntos Re-Estimados al Finalizar la Historia de Usuario'
                data: values
                zIndex: 1
                color: Highcharts.getOptions().colors[0]
                marker:
                    fillColor: 'white'
                    lineWidth: 3
                    lineColor: Highcharts.getOptions().colors[0]
            }
            {
                name: 'Margen aceptable'
                data: ranges
                type: 'arearange'
                lineWidth: 0
                linkedTo: ':previous'
                color: '#566270'
                fillOpacity: 0.3
                zIndex: 0
            }
            {
                name: 'Puntos Estimados al crear la Historia de Usuario'
                data: calculatedValues
                color: Highcharts.getOptions().colors[2]
                marker:
                    fillColor: 'white'
                    lineWidth: 3
                    lineColor: Highcharts.getOptions().colors[2]
            }
          ]
        }

        element.empty()
        Highcharts.chart('error-band-chart', option)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watchGroup ["actualSprint", "slider.value"], (oldValue, newValue) ->
            if $scope.actualSprint?
                redrawChart(element, $scope.actualSprint, $scope.slider.value)
            if $scope.slider.value?
                redrawChart(element, $scope.actualSprint, $scope.slider.value)

        $scope.$on "resize", ->
            redrawChart(element, $scope.actualSprint, $scope.slider.value)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgConfidenceBandDirective", [ConfidenceBandHighcharts])

#############################################################################
## Velocity by Member
#############################################################################
VelocityByMemberDirective = ->
    redrawChart = (element, sprints) ->
        sprintsNames = _.map(sprints, (sprint) -> sprint.name)
        commitedPoints = _.map(sprints, (sprint) -> sprint.commited)
        completedPoints = _.map(sprints, (sprint) -> sprint.completed)

        console.log("****** COMPLETED POINTS")
        console.log(completedPoints)
        console.log("****** COMMITED POINTS")
        console.log(commitedPoints)


        options =
            chart:
                type: 'column'
            title:
                text: ''
            xAxis:
                categories: sprintsNames
                title:
                    text: 'Sprints'
                crosshair: true
            yAxis:
                min: 0
                title:
                    text: 'Puntos (Historias de Usuario)'
            credits: {
                enabled: false
            plorOptions:
                column:
                    pointPadding: 0.2
                    borderWidth:0
            }
            tooltip:
                crosshairs: true
                shared: true
                valueSuffix: ' puntos'

            series: [
                  {
                    name: 'Planeados'
                    data: commitedPoints
                    color: Highcharts.getOptions().colors[0]
                  }
                  {
                    name: 'Completados'
                    data: completedPoints
                    color: Highcharts.getOptions().colors[2]
                  }

            ]


        element.empty()
        Highcharts.chart('velocity-member', options)


    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "completed_points_member", (oldValue, newValue) ->
            if $scope.completed_points_member?
                redrawChart(element, $scope.completed_points_member)

        $scope.$on "resize", ->
            redrawChart(element, $scope.completed_points_member)

        $scope.$on "destroy", ->
            $el.off()
    return {link: link}
angular.module('taigaCustomDashboard').directive("tgVelocityByMemberDirective", [VelocityByMemberDirective])


# #############################################################################
# ## Issues Severity through project directive
# #############################################################################
IssuesSeverityDirective = ->

    findSprint = (date, sprints) ->
      for sprint in sprints.reverse()
          date = moment(date, 'YYYY-MM-DD')
          start = moment(sprint.estimated_start, 'YYYY-MM-DD').format('x')
          end = moment(sprint.estimated_finish, 'YYYY-MM-DD').format('x')
          if date >= start && date <= end
              return sprint


    redrawChart = (element, sprints, issues, project) ->
        sprintsNames = _.map(sprints, (ml) -> ml.name)
        sprintsNames = sprintsNames
        severities = _.map(project.severities, (sv) -> sv.name)
        for sprint in sprints
            sprint.issues = []
            for issue in issues
                if sprint == findSprint(issue.created_date, sprints)
                  sprint.issues.push(issue)

        series = []
        for severity in project.severities
            severity_count = []
            for sprint in sprints
                counts = _.filter(sprint.issues, ((iss) -> iss.severity == severity.id)).length
                severity_count.push(counts)

            serie_data =
              name: severity.name
              data: severity_count
            series.push(serie_data)

        options = {
          chart:
              type: 'column'

          title:
              text: ''
          credits:
              enabled: false
          xAxis:
              categories: sprintsNames
              title:
                  text: 'Sprints'

          yAxis: {
              min: 0
              title:
                  text: 'Número de Riesgos'
              stackLabels:
                  enabled: true
                  style:
                      fontWeight: 'bold'
                      color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'
          }

          tooltip: {
              headerFormat: '<b>{point.x}</b><br/>'
              pointFormat: '{series.name}: {point.y}<br/>Total: {point.stackTotal}'
          }
          plotOptions: {
              column:
                  stacking: 'normal',
                  dataLabels:
                      enabled: true,
                      color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white'
          }
          series: series
        }

        element.empty()
        Highcharts.chart('issues-chart', options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watchGroup ["sprints", "issues", "testProject"], (oldValue, newValue) ->
            if $scope.sprints?
                redrawChart(element, $scope.sprints, $scope.issues, $scope.testProject)

                $scope.$on "resize", ->
                    redrawChart(element, $scope.sprints, $scope.issues, $scope.testProject)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgIssuesSeverityGraph", [IssuesSeverityDirective])

# #############################################################################
# ## Issues Type through project directive
# #############################################################################
IssuesTypeDirective = ->

    findSprint = (date, sprints) ->
      for sprint in sprints.reverse()
          date = moment(date, 'YYYY-MM-DD')
          start = moment(sprint.estimated_start, 'YYYY-MM-DD').format('x')
          end = moment(sprint.estimated_finish, 'YYYY-MM-DD').format('x')
          if date >= start && date <= end
              return sprint


    redrawChart = (element, sprints, issues, project) ->
        sprintsNames = _.map(sprints, (ml) -> ml.name)
        sprintsNames = sprintsNames
        issue_types = _.map(project.issue_types, (sv) -> sv.name)
        console.log("The project from where we get the severities")
        console.log(project)
        for sprint in sprints
            sprint.issues = []
            for issue in issues
                if sprint == findSprint(issue.created_date, sprints)
                  sprint.issues.push(issue)

        series = []
        for type in project.issue_types
            type_count = []
            for sprint in sprints
                counts = _.filter(sprint.issues, ((iss) -> iss.type == type.id)).length
                type_count.push(counts)

            serie_data =
              name: type.name
              data: type_count
            series.push(serie_data)

        options = {
          chart:
              type: 'column'

          title:
              text: ''
          credits:
              enabled: false
          xAxis:
              categories: sprintsNames
              title:
                  text: 'Sprints'

          yAxis: {
              min: 0
              title:
                  text: 'Número de Riesgos'
              stackLabels:
                  enabled: true
                  style:
                      fontWeight: 'bold'
                      color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'
          }

          tooltip: {
              headerFormat: '<b>{point.x}</b><br/>'
              pointFormat: '{series.name}: {point.y}<br/>Total: {point.stackTotal}'
          }
          plotOptions: {
              column:
                  stacking: 'normal',
                  dataLabels:
                      enabled: true,
                      color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white'
          }
          series: series
        }

        element.empty()
        Highcharts.chart('issues-type-chart', options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watchGroup ["sprints", "issues", "testProject"], (oldValue, newValue) ->
            if $scope.sprints?
                redrawChart(element, $scope.sprints, $scope.issues, $scope.testProject)

                $scope.$on "resize", ->
                    redrawChart(element, $scope.sprints, $scope.issues, $scope.testProject)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgIssuesTypeGraph", [IssuesTypeDirective])

# #############################################################################
# ## Issues Status through project directive
# #############################################################################
IssuesStatusDirective = ->

    findSprint = (date, sprints) ->
      for sprint in sprints.reverse()
          date = moment(date, 'YYYY-MM-DD')
          start = moment(sprint.estimated_start, 'YYYY-MM-DD').format('x')
          end = moment(sprint.estimated_finish, 'YYYY-MM-DD').format('x')
          if date >= start && date <= end
              return sprint


    redrawChart = (element, sprints, issues, project) ->
        sprintsNames = _.map(sprints, (ml) -> ml.name)
        sprintsNames = sprintsNames
        issue_types = _.map(project.issue_types, (sv) -> sv.name)
        console.log("The project from where we get the severities")
        console.log(project)
        for sprint in sprints
            sprint.issues = []
            for issue in issues
                if sprint == findSprint(issue.created_date, sprints)
                  sprint.issues.push(issue)

        series = []
        for status in project.issue_statuses
            status_count = []
            for sprint in sprints
                counts = _.filter(sprint.issues, ((iss) -> iss.status == status.id)).length
                status_count.push(counts)

            serie_data =
              name: status.name
              data: status_count
            series.push(serie_data)

        options = {
          chart:
              type: 'column'

          title:
              text: ''
          credits:
              enabled: false
          xAxis:
              categories: sprintsNames
              title:
                  text: 'Sprints'

          yAxis: {
              min: 0
              title:
                  text: 'Peticiones por Prioridad'
              stackLabels:
                  enabled: true
                  style:
                      fontWeight: 'bold'
                      color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'
          }


          tooltip: {
              headerFormat: '<b>{point.x}</b><br/>'
              pointFormat: '{series.name}: {point.y}<br/>Total: {point.stackTotal}'
          }
          plotOptions: {
              column:
                  stacking: 'normal',
                  dataLabels:
                      enabled: true,
                      color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white'
          }
          series: series
        }

        element.empty()
        Highcharts.chart('issues-status-chart', options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watchGroup ["sprints", "issues", "testProject"], (oldValue, newValue) ->
            if $scope.sprints?
                redrawChart(element, $scope.sprints, $scope.issues, $scope.testProject)

                $scope.$on "resize", ->
                    redrawChart(element, $scope.sprints, $scope.issues, $scope.testProject)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgIssuesStatusGraph", [IssuesStatusDirective])


# #############################################################################
# ## Issues Priority through project directive
# #############################################################################
IssuesPriorityDirective = ->

    findSprint = (date, sprints) ->
      for sprint in sprints.reverse()
          date = moment(date, 'YYYY-MM-DD')
          start = moment(sprint.estimated_start, 'YYYY-MM-DD').format('x')
          end = moment(sprint.estimated_finish, 'YYYY-MM-DD').format('x')
          if date >= start && date <= end
              return sprint


    redrawChart = (element, sprints, issues, project) ->
        sprintsNames = _.map(sprints, (ml) -> ml.name)
        sprintsNames = sprintsNames
        issue_priorities = _.map(project.priorities, (sv) -> sv.name)
        console.log("The project from where we get the priori")
        console.log(project)
        for sprint in sprints
            sprint.issues = []
            for issue in issues
                if sprint == findSprint(issue.created_date, sprints)
                  sprint.issues.push(issue)

        series = []
        for priority in project.priorities
            priority_count = []
            for sprint in sprints
                counts = _.filter(sprint.issues, ((iss) -> iss.priority == priority.id)).length
                priority_count.push(counts)

            serie_data =
              name: priority.name
              data: priority_count
            series.push(serie_data)

        options = {
          chart:
              type: 'column'

          title:
              text: ''
          credits:
              enabled: false
          xAxis:
              categories: sprintsNames
              title:
                  text: 'Sprints'

          yAxis: {
              min: 0
              title:
                  text: 'Peticiones por Prioridad'
              stackLabels:
                  enabled: true
                  style:
                      fontWeight: 'bold'
                      color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'
          }


          tooltip: {
              headerFormat: '<b>{point.x}</b><br/>'
              pointFormat: '{series.name}: {point.y}<br/>Total: {point.stackTotal}'
          }
          plotOptions: {
              column:
                  stacking: 'normal',
                  dataLabels:
                      enabled: true,
                      color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white'
          }
          series: series
        }

        element.empty()
        Highcharts.chart('issues-priority-chart', options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watchGroup ["sprints", "issues", "testProject"], (oldValue, newValue) ->
            if $scope.sprints?
                redrawChart(element, $scope.sprints, $scope.issues, $scope.testProject)

                $scope.$on "resize", ->
                    redrawChart(element, $scope.sprints, $scope.issues, $scope.testProject)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgIssuesPriorityGraph", [IssuesPriorityDirective])


#############################################################################
## Sprint Userstories Percentage directive
#############################################################################
SprintUserstoriesPercentDirective = ->
    link = ($scope, $el, $attrs) ->
            element = angular.element($el)
            step = element.find('.pie-value')
            $scope.$watch "sprintStats", (oldValue, newValue) ->
                if $scope.sprintStats?
                    valuePercentage = $scope.sprintStats.completedPercentageUserstories
                else
                    valuePercentage = 0
                $(element).easyPieChart({
                    barColor: '#68b828'
                    scaleColor: false
                    trackColor: '#eee'
                    lineCap: 'round'
                    lineWidth: 8
                    animate: 1000
                    onStep: (value) -> step.text(value + '%')
                    onStop: (value, to) -> step.text(to + '%')
                }).data('easyPieChart').update(valuePercentage)
      return {link: link}
angular.module("taigaCustomDashboard").directive("tgSprintPercentUserstoriesDirective", [SprintUserstoriesPercentDirective])
