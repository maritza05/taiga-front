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


    ]

    milestonesOrder: {}

    constructor: (@scope, @currentUserService, @projectsService, @rs, @errorHandlingService) ->
        @.loadMainProjects()
        taiga.defineImmutableProperty(@, "allprojects", () => @scope.projectsTry)
        @scope.data = @allprojects
        console.log("The is the actual scope data:")
        console.log(@currentUserService.projects.get('all'))

    loadMainProjects: () ->
          return @rs.projects.list('all').then (result) =>
            @scope.projectsTry = Immutable.fromJS(result)
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


    setProject: (project) ->
        @scope.project = project
        @scope.projectId = project.id
        promise = @.loadInitialData(@scope.projectId)
        promise.then =>
            console.log("Sprints:")
            console.log(@scope.sprints)
            console.log("This are the statuses")
            console.log(@scope.testProject.us_statuses)
            console.log("This is the entire project")
            console.log(@scope.testProject)
            @scope.userstories_status = @scope.testProject.us_statuses
            @scope.members = _.filter(@scope.testProject.members, ((user) -> user.is_active == true))
            console.log("--------Members:")
            @.loadMembersStats(@scope.members)
            console.log(@scope.members)

            console.log("-------The issues")
            console.log(@scope.issues)

    setMember: (member) ->
        sprintMember = []
        console.log("-----This are the sprints")
        for sprint in @scope.sprints
            userstories_m = _.filter(sprint.user_stories, ((story) -> story.assigned_to == member.id))
            completed_u = 0
            commited_u = 0
            for userstory in userstories_m
                totalpoints = userstory.total_points
                commited_u += totalpoints
                if userstory.is_closed
                    completed_u += totalpoints
            sprintMember.push({ "name" : sprint.name, "commited": commited_u, "completed": completed_u})
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
CustomBurndownGraphDirective =  ->

    redrawChart = (chart, dataToDraw) ->
        milestonesRange = [0..(dataToDraw.milestones.length - 1)]
        milestonesNames = _.map(dataToDraw.milestones, (ml) -> ml.name)
        optimal_line = _.map(dataToDraw.milestones, (ml) -> ml.optimal)
        evolution_line = _.filter(_.map(dataToDraw.milestones, (ml) -> ml.evolution), (evolution) -> evolution? )
        client_increment_line = _.map(dataToDraw.milestones, (ml) -> ml["client-increment"])

        options =

          tooltip:
            backgroundColor: 'rgba(50, 50, 50, 0.5)'
            axisPointer:
              type: 'line'
              lineStyle:
                color: "#008acd"
              crossStyle:
                color: "#008acd"
              shadowStyle:
                color: 'rgba(200, 200, 200, 0.2)'
            trigger: 'axis'
          legend:
            data: [
              'Optimal'
              'Evolution'
              'Client Increment'
            ]
          showXAxis: true
          showYAxis: true
          showLegend: true
          stack: false
          toolbox:
            show: true
            showTitle: true
            color: [
              '#bdbdbd'
              '#bdbdbd'
              '#bdbdbd'
              '#bdbdbd'
            ]
            feature:
              mark:
                show: true
              dataZoom:
                show: true
              dataView:
                show: false
              restore:
                show: false
              saveAsImage:
                show: true
              magicType:
                show: true
                itemSize: 12
                itemGap: 12
                title:
                  line: 'Line'
                  bar: 'Bar'
                type: [
                  'line'
                  'bar'
                  'stack'
                  'tiled'
                ]
          xAxis: [
            type: 'category'
            boundaryGap: false
            data: milestonesNames
          ]
          yAxis: [
            onZero: true
          ]
          series: [
            {
                name: 'Optimal'
                type: 'line'
                smooth: true
                itemStyle:
                  normal:
                    areaStyle:
                      type: 'default'
                data: optimal_line
            }
            {
                name: 'Evolution'
                type: 'line'
                smooth: true
                itemStyle:
                  normal:
                    areaStyle:
                      type: 'default'
                data: evolution_line
            }
            {
                name: 'Client Increment'
                type: 'line'
                smooth: true
                itemStyle:
                  normal:
                    areaStyle:
                      type: 'default'
                data: client_increment_line
            }

          ]

        chart.setOption(options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)
        ndWrapper = element[0]
        ndParent = element.parent()[0]

        getSizes = () ->
            width = ndParent.clientWidth
            height = ndParent.clientHeight
            ndWrapper.style.width = width + 'px'
            ndWrapper.style.height = height + 'px'

        getSizes()
        chart = echarts.init(ndWrapper, 'macarons')

        $scope.$watch "stats", (value) ->

            if $scope.stats?
                chart.clear()
                redrawChart(chart, $scope.stats)

        $scope.$on "resize", ->
            getSizes()
            chart.resize()

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}

angular.module("taigaCustomDashboard").directive("tgCustomBurndownGraph", [CustomBurndownGraphDirective])

#############################################################################
## Burndown graph directive
#############################################################################
BurndownFlotGraphDirective = ->
    redrawChart = (element, dataToDraw) ->
        console.log("----Statistics")
        console.log(dataToDraw)
        milestonesRange = [0..(dataToDraw.milestones.length - 1)]
        milestonesNames = _.map(dataToDraw.milestones, (ml) -> ml.name)
        optimal_line = _.map(dataToDraw.milestones, (ml) -> ml.optimal)
        evolution_line = _.filter(_.map(dataToDraw.milestones, (ml) -> ml.evolution), (evolution) -> evolution? )
        client_increment_line = _.map(dataToDraw.milestones, (ml) -> ml["client-increment"])
        data = []
        data.push({
            label: 'Actual Evolution'
            data: _.zip(milestonesRange, evolution_line)
            lines:
              show: true
              lineWidth: 2
              fill: true
              fillColor:
                colors: [{opacity: 0.5}, {opacity: 0.5}]
            points:
              show: true
              radius: 4
        })
        data.push({
            label: 'Optimal'
            data: _.zip(milestonesRange, optimal_line)
            lines:
              show: true
              lineWidth: 2
              fill: true
              fillColor:
                colors: [{opacity: 0.5}, {opacity: 0.5}]
            points:
              show: true
              radius: 4
        })

        options = {
            series: {
                lines:
                    show: true
                points:
                    show: true
                shadowSize: 0
            }
            colors: ['#177bbb', '#177bbb']
            legend: {
                show: true,
                position: 'nw'
                margin: [15, 0]
            }
            grid: {
                borderWidth: 0
                hoverable: true
                clickable: true
            }
            yaxis:
                ticks: 4
                tickColor: '#eeeeee'
            xaxis:
                ticks: 12
                tickColor: '#ffffff'
        }

        # element.empty()
        # element.plot(data, options)
        options2 = {
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
                    text: 'Points'
                }
                labels: {
                    formatter: () ->
                        return this.value
                }
            tooltip: {
                formatter:  () ->
                    return '<b>' +  this.series.name + '</b><br/>' + '<b>'+'Sprint: ' + '</b>' +  this.x+'<br/><b>'+ 'Points: ' +'</b>' + Math.round(this.y)

            }

            plotOptions:
                area:
                    fillOpactiy: 0.2


            credits: {
                enabled: false
            }
            series: [
                {
                    name: 'Optimal'
                    color: '#DDDDDD'
                    data: optimal_line
                    marker:
                        fillColor: '#DDDDDD'
                        lineWidth: 3
                        lineColor: '#DDDDDD'
                }
                {
                    name: 'Evolution'
                    data: evolution_line
                    marker:
                        fillColor: 'rgba(54,184,213, 0.7)'
                        lineWidth: 3
                        lineColor: '38B8D5'
                }
            ]
        }
        element.empty()
        Highcharts.chart('high1', options2)


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

angular.module("taigaCustomDashboard").directive("tgBurndownFlotDirective", [BurndownFlotGraphDirective])





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
    link = ($scope, $el, $attrs) ->
            element = angular.element($el)
            step = element.find('.pie-value')

            $scope.$watchGroup ["sprints", "currentSprint"], (oldValue, newValue) ->
                sprintsClosedPoints = _.map($scope.sprints, (ml) -> ml.closed_points)
                for point, index in sprintsClosedPoints
                    sprintsClosedPoints[index] = 0 if point == null
                totalClosedPoints = _.reduce(sprintsClosedPoints, ((memo, num) -> memo + num), 0)
                avgPoints = totalClosedPoints / sprintsClosedPoints.length
                sprintsTotalPoints = _.map($scope.sprints, (ml) -> ml.total_points)
                totalPoints = _.reduce(sprintsTotalPoints, ((memo, num) -> memo + num), 0)
                avgTotalPoints = totalPoints / sprintsTotalPoints.length
                deviation = 100 * (Math.abs(avgPoints-avgTotalPoints)) / avgTotalPoints
                if isNaN(deviation)
                    deviation = 0
                deviation = Math.round(deviation)
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
                count = 0
                for issue in $scope.issues
                  if issue.is_closed
                    count += 1
                avg = Math.round((count * 100) / $scope.issues.length)
                $(element).easyPieChart({
                      barColor: '#fff'
                      scaleColor: false
                      trackColor: '#914887'
                      lineCap: 'butt'
                      lineWidth: 8
                      animate: 1000
                      onStep: (value) -> step.text(value + '%')
                      onStop: (value, to) -> step.text(to + '%')
                  }).data('easyPieChart').update(avg)
      return {link: link}
angular.module("taigaCustomDashboard").directive("tgProjectCompletedIssuesDirective", [ProjectCompletedIssuesDirective])

#############################################################################
## Velocity gauge directive
#############################################################################
ProjectVelocityGauge = ->
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
                strokeColor: '#914887'
                generateGradient: true
            element = angular.element($el)
            canv = element[0]
            $scope.$watch "stats", (oldValue, newValue) ->
                gauge = new Gauge(canv).setOptions(opts)
                gauge.maxValue = 100
                gauge.animationSpeed = 32
                gauge.set(57)
                gauge.setTextField('40%')
    return {link: link}
angular.module("taigaCustomDashboard").directive("tgVelocityDirective", [ProjectVelocityGauge])



#############################################################################
## Velocity graph directive
#############################################################################
CustomVelocityGraphDirective = ->

    redrawChart = (chart, dataToDraw) ->
        sprintsNames = _.map(dataToDraw, (ml) -> ml.name)
        sprintsNames = sprintsNames.reverse()
        sprintsClosedPoints = _.map(dataToDraw, (ml) -> ml.closed_points)
        sprintsClosedPoints = sprintsClosedPoints.reverse()
        for point, index in sprintsClosedPoints
            sprintsClosedPoints[index] = 0 if point == null

        sprintsTotalPoints = _.map(dataToDraw, (ml) -> ml.total_points)
        sprintsTotalPoints = sprintsTotalPoints.reverse()

        options =
          tooltip:
            trigger: 'axis'
          legend:
            data: [
              'Commitment'
              'Completed'
            ]
          showXAxis: true
          showYAxis: true
          showLegend: true
          stack: false
          toolbox:
            show: true
            feature:
              restore:
                show: true
              saveAsImage:
                show: true
              magicType:
                show: true
                title:
                  line: 'Line'
                  bar: 'Bar'
                type: [
                  'line'
                  'bar'
                  'stack'
                  'tiled'
                ]
          xAxis: [
            type: 'category'
            boundaryGap: true
            data: sprintsNames
          ]
          yAxis: [
            type: 'value'
          ]
          series: [
            {
                name: 'Commitment'
                type: 'bar'
                data: sprintsTotalPoints
                markLine:
                  data: [
                    type: 'average'
                    name: 'Average'
                  ]

            }
            {
                name: 'Completed'
                type: 'bar'
                data: sprintsClosedPoints
                markLine:
                  data: [
                    type: 'average'
                    name: 'Average'
                  ]
            }

          ]

        options2 = {
          chart:
              type: 'column'

          title:
              text: ''

          xAxis:
              categories: ['Apples', 'Oranges', 'Pears', 'Grapes', 'Bananas']

          yAxis: {
              min: 0
              title:
                  text: 'Total fruit consumption'
              stackLabels:
                  enabled: true
                  style:
                      fontWeight: 'bold'
                      color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'
          }
          legend:
              align: 'right'
              x: -30
              verticalAlign: 'top'
              y: 25
              floating: true
              backgroundColor: (Highcharts.theme && Highcharts.theme.background2) || 'white'
              borderColor: '#CCC'
              borderWidth: 1
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
          series: [
              {
                  name: 'John'
                  data: [5, 3, 4, 7, 2]
              }
              {
                  name: 'Jane'
                  data: [2, 2, 3, 2, 1]
              }
              {
                  name: 'Joe',
                  data: [3, 4, 4, 2, 5]
              }
          ]
        }


        element.empty()
        Highcharts.chart('high2', options2)

        # chart.setOption(options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)
        ndWrapper = element[0]
        ndParent = element.parent()[0]

        getSizes = () ->
            width = ndParent.clientWidth
            height = ndParent.clientHeight
            ndWrapper.style.width = width + 'px'
            ndWrapper.style.height = 378 + 'px'

        getSizes()
        console.log("Echarts: ", echarts == undefined)
        chart = echarts.init(ndWrapper, 'macarons')

        $scope.$watch "sprints", (value) ->

            if $scope.sprints?
                chart.clear()
                redrawChart(chart, $scope.sprints)

        $scope.$on "resize", ->
            getSizes()
            chart.resize()

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgCustomVelocityGraph", [CustomVelocityGraphDirective])


#############################################################################
## CustomBurndownHighchart graph directive
#############################################################################
CustomBurndownHighchartAddDirective = ->

    redrawChart = (element,dataToDraw) ->
        milestonesRange = [0..(dataToDraw.milestones.length - 1)]
        milestonesNames = _.map(dataToDraw.milestones, (ml) -> ml.name)
        closed_points = _.filter(_.map(dataToDraw.milestones, (ml) -> ml.evolution), (evolution) -> evolution? )
        client_increment_line = _.map(dataToDraw.milestones, (ml) -> ml["client-increment"])
        evolution = []
        for point, i in closed_points
            if i > 0
                change = (closed_points[i-1] - point) * -1
            else
                change = 0
            evolution.push(change)
        numberSprints = _.filter(dataToDraw.milestones, (ml) -> ml.name not in ['Future sprint', 'Project End'])
        console.log("Sprints that are not future! or end")
        console.log(numberSprints)
        evolutionNotFuture = []
        for sprint, i in numberSprints
            if i > 0
                change = numberSprints[i-1].evolution - sprint.evolution
            else
                change = 0
            evolutionNotFuture.push(change)
        console.log("Evolution without future")
        console.log(evolutionNotFuture)
        if evolutionNotFuture.length > 3
            speed = _.reduce(evolutionNotFuture, ((res, n) -> res + n), 0)
            avg_speed = Math.round(speed / evolutionNotFuture.length)
        last_remind = closed_points[closed_points.length-1]
        message = element.find('.text-semibold')
        if avg_speed > 0
            needed_sprints = Math.round(last_remind / avg_speed)
            message.text("You'll need " + avg_speed + " sprints more to complete the project")
        else
          needed_sprints = 0
          message.text('')



        options2 = {
          chart:
              type: 'column'

          title:
              text: ''

          xAxis:
              categories: milestonesNames

          yAxis: {
              tickInterval: 200
              title:
                  text: 'Total fruit consumption'
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
          series: [
              {
                  name: 'Work completed'
                  data: evolution
                  color: '#E3ECC8'
              }
              {
                  name: 'Work remaining'
                  data: closed_points
                  color: '#90EE90'
              }
              {
                 name: 'Work added'
                 data: client_increment_line
                 color: '#577CA0'
              }
          ]
        }


        element.empty()
        Highcharts.chart('high2', options2)

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
angular.module("taigaCustomDashboard").directive("tgCustomBurndownHighchartAddGraph", [CustomBurndownHighchartAddDirective])

###########################################################################
## Prediction Burndown Chart
###########################################################################
SprintsPredictionDirective = ->
    redrawChart = (element,dataToDraw) ->
        milestonesRange = [0..(dataToDraw.milestones.length - 1)]
        milestonesNames = _.map(dataToDraw.milestones, (ml) -> ml.name)
        closed_points = _.filter(_.map(dataToDraw.milestones, (ml) -> ml.evolution), (evolution) -> evolution? )
        client_increment_line = _.map(dataToDraw.milestones, (ml) -> ml["client-increment"])
        evolution = []
        for point, i in closed_points
            if i > 0
                change = (closed_points[i-1] - point) * -1
            else
                change = 0
            evolution.push(change)
        numberSprints = _.filter(dataToDraw.milestones, (ml) -> ml.name not in ['Future sprint', 'Project End'])
        evolutionNotFuture = []
        for sprint, i in numberSprints
            if i > 0
                change = numberSprints[i-1].evolution - sprint.evolution
            else
                change = 0
            evolutionNotFuture.push(change)

        if evolutionNotFuture.length > 3
            speed = _.reduce(evolutionNotFuture, ((res, n) -> res + n), 0)
            avg_speed = Math.round(speed / evolutionNotFuture.length)
        last_remind = closed_points[closed_points.length-1]
        if avg_speed > 0
            needed_sprints = Math.round(last_remind / avg_speed)
            message = element.find('.prediction')
            message.text("You'll need " + needed_sprints + " sprints more to complete the project")
        else
          needed_sprints = 0
    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watchGroup ["stats", "project"], (oldValue, newValue) ->
            if $scope.project?
                element.find('.text-semibold').text('')
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



        options2 = {
            chart:
                type: 'column'

            title:
                text: ''

            xAxis: {
                categories: sprintsNames
                crosshair: true
            }
            yAxis: {
                min: 0
                title:
                    text: 'Rainfall (mm)'

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
                    name: 'Completed Points',
                    data: sprintsClosedPoints

                }
                {
                    name: 'Commited Points'
                    data:  sprintsTotalPoints
                }

            ]
        }


        element.empty()
        Highcharts.chart('high3', options2)

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
## Mean shpuld be velocity gauge directive
#############################################################################
ProjectShouldVelocityGauge = ->
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
                strokeColor: '#914887'
                generateGradient: true
            element = angular.element($el)
            canv = element[0]

            $scope.$watch "sprints", (oldValue, newValue) ->
                totalPoints = 0
                size = $scope.sprints.length
                for sprint in $scope.sprints
                    if sprint.closed_points >= 0
                        totalPoints += sprint.total_points
                if size
                    total_percent = Math.round(totalPoints/size)
                else
                    total_percent = 0
                console.log("TotL PERCENT OF GAUGE: " + total_percent+ " SIZE: "+size)
                gauge = new Gauge(canv).setOptions(opts)
                gauge.maxValue = total_percent
                gauge.animationSpeed = 32
                gauge.set(total_percent)
                gauge.setTextField(total_percent+'%')
    return {link: link}
angular.module("taigaCustomDashboard").directive("tgProjectShouldVelocityGauge", [ProjectShouldVelocityGauge])

#############################################################################
## Mean is velocity gauge directive
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
                strokeColor: '#914887'
                generateGradient: true
            element = angular.element($el)
            canv = element[0]

            $scope.$watch "sprints", (oldValue, newValue) ->
                completedPoints = 0
                totalPoints = 0
                size = $scope.sprints.length
                for sprint in $scope.sprints
                    if sprint.closed_points
                        completedPoints += sprint.closed_points
                    if sprint.total_points
                        totalPoints += sprint.total_points
                if size
                    total_percent = Math.round(completedPoints/size)
                    total_should_percent = Math.round(totalPoints/size)
                else
                    total_percent = 0
                    total_should_percent = 0
                console.log("TotL PERCENT OF GAUGE: is" + total_percent+ " SIZE: "+size)
                gauge = new Gauge(canv).setOptions(opts)
                gauge.maxValue = total_should_percent
                gauge.animationSpeed = 32
                gauge.set(total_percent)
                gauge.setTextField(total_percent+'%')
    return {link: link}
angular.module("taigaCustomDashboard").directive("tgProjectIsVelocityGauge", [ProjectIsVelocityGauge])






#############################################################################
## Comulative workflow directive
#############################################################################
CustomCumulativeWorkflowDirective = ->
    redrawChart = (chart, sprints, us_statuses) ->
        sprintsNames = _.map(sprints, (ml) -> ml.name)
        sprintsNames = sprintsNames.reverse()
        us_statusesNames = _.map(us_statuses, (us) -> us.name)
        us_ids = _.map(us_statuses, (us) -> us.id)
        data = []
        for status in us_statuses
            status_data = []
            for sprint, index in sprints
                counter = 0
                for userstory in sprint.user_stories
                    if userstory.status == status.id
                        counter = counter + 1
                status_data[index] = counter
            data.push(status_data)

        console.log("**Data")
        console.log(data)
        console.log("Userstories")
        for sprint in sprints
            console.log("The name: #{sprint.name}")
            for userstory in sprint.user_stories
                console.log("Status: #{userstory.status}")

        series = []
        for serie, index in data
            item =
              name: us_statusesNames[index]
              type: 'bar'
              data: serie
            series.push(item)

        options =
          tooltip:
            trigger: 'axis'
          legend:
            data: us_statusesNames
          showXAxis: true
          showYAxis: true
          showLegend: true
          stack: false
          toolbox:
            show: true
            feature:
              restore:
                show: true
              saveAsImage:
                show: true
              magicType:
                show: true
                title:
                  line: 'Line'
                  bar: 'Bar'
                type: [
                  'line'
                  'bar'
                  'stack'
                  'tiled'
                ]
          xAxis: [
            type: 'category'
            boundaryGap: true
            data: sprintsNames
          ]
          yAxis: [
            type: 'value'
          ]
          series: series

        chart.setOption(options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)
        ndWrapper = element[0]
        ndParent = element.parent()[0]

        getSizes = () ->
            width = ndParent.clientWidth
            height = ndParent.clientHeight
            ndWrapper.style.width = width + 'px'
            ndWrapper.style.height = 378 + 'px'

        getSizes()
        chart = echarts.init(ndWrapper, 'macarons')

        $scope.$watchGroup ["sprints", "userstories_status"], (oldValue, newValue) ->
            if $scope.sprints?
                chart.clear()
                redrawChart(chart, $scope.sprints, $scope.userstories_status)

        $scope.$on "resize", ->
            getSizes()
            chart.resize()

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgCustomComulativeWorkflowGraph", [CustomCumulativeWorkflowDirective])

#############################################################################
## Issues Severity through project directive
#############################################################################
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
                console.log("The count for the sprint: #{sprint.name}: #{counts}")
                severity_count.push(counts)

            serie_data =
              name: severity.name
              data: severity_count
            series.push(serie_data)

        console.log("---- Series")
        console.log(series)

        for sprint in sprints.reverse()
            console.log("The issues of sprint: #{sprint.name}")
            console.log(sprint.issues)

        console.log("Issues statuses: ")
        console.log(project.severities)

        options =
          tooltip:
            trigger: 'axis'
            axisPointer:
              type: 'shadow'
          legend:
            data: severities
          grid:
            containLabel: true

          toolbox:
            show: true
            feature:
              restore:
                show: true
              saveAsImage:
                show: true
              magicType:
                show: true
                title:
                  line: 'Line'
                  bar: 'Bar'
                type: [
                  'line'
                  'bar'
                  'stack'
                  'tiled'
                ]
          xAxis: [
            type: 'value'
          ]
          yAxis: [
            type: 'category'
            data: sprintsNames
          ]
          series: series


        options2 = {
          chart:
              type: 'column'

          title:
              text: ''

          xAxis:
              categories: sprintsNames

          yAxis: {
              min: 0
              title:
                  text: 'Total fruit consumption'
              stackLabels:
                  enabled: true
                  style:
                      fontWeight: 'bold'
                      color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'
          }
          legend:
              align: 'right'
              x: -30
              verticalAlign: 'top'
              y: 25
              floating: true
              backgroundColor: (Highcharts.theme && Highcharts.theme.background2) || 'white'
              borderColor: '#CCC'
              borderWidth: 1
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
          series: series
        }


        element.empty()
        Highcharts.chart('high4', options2)

        # console.log("******** The options of the chart")
        # console.log(options)
        # chart.setOption(options)

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

#############################################################################
## Confidence in Estimations directive
#############################################################################
ConfidencePointsDirective = ->

    redrawChart = (chart, sprints) ->
        sprintsNames = _.map(sprints, (ml) -> ml.name)
        sprintsNames = sprintsNames.reverse()
        sprintUserstories = _.map(sprints, (sp) -> sp.user_stories)
        max = 0
        for sp_us in sprintUserstories
          if sp_us.length > max
            max = sp_us.length

        points = 0
        data_object = []
        series_data = []
        for sprint in sprints.reverse()
            console.log("======The userstory data")
            console.log(sprint.user_stories)
            lower_bound = []
            upper_bound = []
            actual_val = []
            estimated_val = []

            for userstory in sprint.user_stories
                sumEstimatedPoints = _.reduce(_.values(userstory.points), ((res, n) -> res + n), 0)
                realPoints = userstory.real_total_points
                percent = (10 * realPoints)/100
                lower_percent = realPoints - percent
                upper_percent = realPoints + percent
                lower_bound.push(lower_percent)
                upper_bound.push(upper_percent)
                actual_val.push(realPoints)
                estimated_val.push(sumEstimatedPoints)

            data =
              {
                title:
                  text: "Confidence Band #{sprint.name}"
                series: [
                  {data: lower_bound},
                  {data: upper_bound},
                  {data: actual_val},
                  {data: estimated_val}
                ]
              }

            series_data.push(data)

        console.log("-->>>>>>>Series object")
        console.log(series_data)


        option =
          baseOption:
            timeline:
              axisType: 'category'
              data: sprintsNames
              autoPlay: true
              playInterval: 1000
            tooltip:
              trigger: 'axis'
              axisPointer:
                type: 'shadow'
            grid:
              containLabel: true

            toolbox:
              show: true
              feature:
                restore:
                  show: true
                saveAsImage:
                  show: true
                magicType:
                  show: true
                  title:
                    line: 'Line'
                    bar: 'Bar'
                  type: [
                    'line'
                    'bar'
                    'stack'
                    'tiled'
                  ]
            xAxis: [
              type: 'category'
              data: [1..max]
              splitLine:
                show: false
              boundaryGap: false
            ]
            yAxis:
              axisLabel:
                formatter: (val) ->
                  val + '%'
              splitNumber: 3
              splitLine:
                show: false
            series: [
              {
                name: 'L'
                type: 'line'
                lineStyle:
                  normal:
                    opacity: 0
                stack: 'confidence-band'
                symbol: 'none'
              },
              {
                name: 'U'
                type: 'line'
                lineStyle:
                  normal:
                    opacity: 0
                areaStyle:
                  normal:
                    color: '#ccc'
                stack: 'confidence-band'
                symbol: 'none'
              },
              {
                type: 'line'
                hoverAnimation: false
                symbolSize: 6
                itemStyle:
                  normal:
                    color: "#c23531"
                showSymbol: false
              },
              {
                name: 'Estimation'
                type: 'line'
                itemStyle:
                  normal:
                    color: "#2EC7C9"
              }
            ]
          options: series_data
          # options: [
          #   {
          #     title:
          #       text: "Confidence Band Sprint1"
          #     series: [
          #       {data: [-10, -20, -30, -40, -50, -60]},
          #       {data: [10, 20, 30, 40, 50, 60]},
          #       {data: [15, 23, 23, 34, 45, 23]},
          #       {data: [15, 23, 23, 34, 45, 23]}
          #     ]
          #   },
          #   {
          #     title:
          #       text: "Confidence Band Sprint2"
          #     series: [
          #       {data: [-4, -20, -12, -30, -30, -10]},
          #       {data: [14, 34, 45, 13, 23, 45]},
          #       {data: [10, 12, 11, 13, 12, 10]},
          #       {data: [15, 23, 23, 34, 45, 23]}
          #     ]
          #   },
          #   {
          #     title:
          #       text: "Confidence Band Sprint3"
          #     series: [
          #       {data: [-10, -20, -30, -40, -50, -60]},
          #       {data: [10, 20, 30, 40, 50, 60]},
          #       {data: [15, 23, 23, 34, 45, 23]},
          #       {data: [15, 23, 23, 34, 45, 23]}
          #     ]
          #   },
          #   {
          #     title:
          #       text: "Confidence Band Sprint4"
          #     series: [
          #       {data: [-4, -20, -12, -30, -30, -10]},
          #       {data: [14, 34, 45, 13, 23, 45]},
          #       {data: [10, 12, 11, 13, 12, 10]},
          #       {data: [15, 23, 23, 34, 45, 23]}
          #     ]
          #   }
          # ]


        chart.setOption(option)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)
        ndWrapper = element[0]
        ndParent = element.parent()[0]

        getSizes = () ->
            width = ndParent.clientWidth
            height = ndParent.clientHeight
            ndWrapper.style.width = width + 'px'
            ndWrapper.style.height = 378 + 'px'

        getSizes()
        chart = echarts.init(ndWrapper, 'macarons')

        $scope.$watch "sprints", (oldValue, newValue) ->
            if $scope.sprints?
                chart.clear()
                redrawChart(chart, $scope.sprints)

        $scope.$on "resize", ->
            getSizes()
            chart.resize()

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgConfidencePointsGraph", [ConfidencePointsDirective])


#############################################################################
## Confidence in Estimations Highchart directive
#############################################################################
ConfidenceBandHighcharts = ->

    redrawChart = (element, sprint) ->
        ranges = []
        values = []
        calculatedValues = []
        console.log("Checking the userstories")
        console.log(sprint)
        for userstory, i in sprint.user_stories
            sumEstimatedPoints = _.reduce(_.values(userstory.points), ((res, n) -> res + n), 0)
            realPoints = userstory.real_total_points
            percent = (30 * realPoints)/100
            lower_percent = realPoints - percent
            upper_percent = realPoints + percent

            values.push([i, realPoints])
            ranges.push([i, lower_percent, upper_percent])
            calculatedValues.push([i, sumEstimatedPoints])

        console.log("Ranges")
        console.log(ranges)

        console.log("Values")
        console.log(values)

        option = {
          title:
              text: ''
          xAxis:
              type: 'category'
          yAxis:
              title:
                  text: 'Margin error'
              tickInterval: 50
          tooltip:
              crosshairs: true
              shared: true
              valueSuffix: '°C'
          series: [
            {
                name: 'Temperature'
                data: values
                zIndex: 1
                marker:
                    fillColor: 'white'
                    lineWidth: 2
                    lineColor: Highcharts.getOptions().colors[0]
            }
            {
                name: 'Range'
                data: ranges
                type: 'arearange'
                lineWidth: 0
                linkedTo: ':previous'
                color: Highcharts.getOptions().colors[0]
                fillOpacity: 0.3
                zIndex: 0
            }
            {
                name: 'Estimated values'
                data: calculatedValues
                marker:
                    fillColor: 'white'
                    lineWidth: 2
                    lineColor: Highcharts.getOptions().colors[2]
            }
          ]
        }

        element.empty()
        Highcharts.chart('error-band-chart', option)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "actualSprint", (oldValue, newValue) ->
            if $scope.actualSprint?
                redrawChart(element, $scope.actualSprint)

        $scope.$on "resize", ->
            redrawChart(element, $scope.actualSprint)

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgConfidenceBandDirective", [ConfidenceBandHighcharts])
#############################################################################
## Sprint Points Percentage directive
#############################################################################
SprintPercentDirective = ->
    link = ($scope, $el, $attrs) ->
            element = angular.element($el)
            step = element.find('.step')
            console.log("Step: ")
            console.log(step)
            $scope.$watch "sprintStats", (oldValue, newValue) ->
                $(element).easyPieChart({
                    barColor: '#68b828'
                    scaleColor: false
                    trackColor: '#eee'
                    lineCap: 'round'
                    lineWidth: 8
                    animate: 1000
                    onStep: (value) -> step.text(value + '%')
                    onStop: (value, to) -> step.text(to + '%')
                }).data('easyPieChart').update($scope.sprintStats.completedPercentage)
      return {link: link}
angular.module("taigaCustomDashboard").directive("tgSprintPercentDirective", [SprintPercentDirective])

#############################################################################
## Sprint Userstories Percentage directive
#############################################################################
SprintUserstoriesPercentDirective = ->
    link = ($scope, $el, $attrs) ->
            element = angular.element($el)
            step = element.find('.step')
            $scope.$watch "sprintStats", (oldValue, newValue) ->
                $(element).easyPieChart({
                    barColor: '#68b828'
                    scaleColor: false
                    trackColor: '#eee'
                    lineCap: 'round'
                    lineWidth: 8
                    animate: 1000
                    onStep: (value) -> step.text(value + '%')
                    onStop: (value, to) -> step.text(to + '%')
                }).data('easyPieChart').update($scope.sprintStats.completedPercentageUserstories)
      return {link: link}
angular.module("taigaCustomDashboard").directive("tgSprintPercentUserstoriesDirective", [SprintUserstoriesPercentDirective])

#############################################################################
## Sprint stats directive
#############################################################################
SprintStatsDirective = ->
    redrawChart = (chart, sprintStats) ->
        days = sprintStats.days
        dayName = _.map(days, (sp) -> sp.name)
        optimalPoints = _.map(days, (sp) -> sp.optimal_points)
        actualPoints = _.map(days, (sp) -> sp.open_points)


        console.log("This are the days names: ")
        console.log(dayName)
        console.log("Optimal Points")
        console.log(optimalPoints)
        console.log("Actual points")
        console.log(actualPoints)

        options =
          tooltip:
            trigger: 'axis'
          legend:
            data: ['Actual', 'Optimal']
          showXAxis: true
          showYAxis: true
          showLegend: true
          stack: false
          toolbox:
            show: true
            feature:
              restore:
                show: true
              saveAsImage:
                show: true
              magicType:
                show: true
                title:
                  line: 'Line'
                  bar: 'Bar'
                type: [
                  'line'
                  'bar'
                  'stack'
                  'tiled'
                ]
          xAxis: [
            type: 'category'
            boundaryGap: true
            data: dayName
          ]
          yAxis: [
            type: 'value'
          ]
          series: [
            {
                name: 'Actual'
                type: 'line'
                data: actualPoints
            }
            {
                name: 'Optimal'
                type: 'line'
                data: optimalPoints
            }
          ]

        chart.setOption(options)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)
        ndWrapper = element[0]
        ndParent = element.parent()[0]

        getSizes = () ->
            width = ndParent.clientWidth
            height = ndParent.clientHeight
            ndWrapper.style.width = width + 'px'
            ndWrapper.style.height = 378 + 'px'

        getSizes()
        chart = echarts.init(ndWrapper, 'macarons')

        $scope.$watch "sprintStats", (oldValue, newValue) ->
            if $scope.sprintStats?
                chart.clear()
                redrawChart(chart, $scope.sprintStats)

        $scope.$on "resize", ->
            getSizes()
            chart.resize()

        $scope.$on "destroy", ->
            $el.off()

    return {link: link}
angular.module("taigaCustomDashboard").directive("tgSprintStatsGraph", [SprintStatsDirective])

#############################################################################
## Userstory points by Sprint and Member directive
#############################################################################
MemberVelocityDirective = ->
    redrawChart = (chart, memberStats) ->
        names = _.map(memberStats, (st) -> st.name)
        console.log("Names")
        console.log(names)
        commited = _.map(memberStats, (st) -> st.commited)
        console.log("Commited")
        console.log(commited)
        completed = _.map(memberStats, (st) -> st.completed)
        console.log("Completed")
        console.log(completed)
        options =
          tooltip:
            trigger: 'axis'
          legend:
            data: ['Commited', 'Completed']
          showXAxis: true
          showYAxis: true
          showLegend: true
          stack: false
          toolbox:
            show: true
            feature:
              restore:
                show: true
              saveAsImage:
                show: true
              magicType:
                show: true
                title:
                  line: 'Line'
                  bar: 'Bar'
                type: [
                  'line'
                  'bar'
                  'stack'
                  'tiled'
                ]
          xAxis: [
            type: 'category'
            boundaryGap: true
            data: names
          ]
          yAxis: [
            type: 'value'
          ]
          series: [
            {
                name: 'Commited'
                type: 'bar'
                data: commited
            }
            {
                name: 'Completed'
                type: 'bar'
                data: completed
            }
          ]
        chart.setOption(options)
    link = ($scope, $el, $attrs) ->
        element = angular.element($el)
        ndWrapper = element[0]
        ndParent = element.parent()[0]

        getSizes = () ->
            width = ndParent.clientWidth
            height = ndParent.clientHeight
            ndWrapper.style.width = width + 'px'
            ndWrapper.style.height = 378 + 'px'

        getSizes()
        chart = echarts.init(ndWrapper, 'macarons')

        $scope.$watch "completed_points_member", (oldValue, newValue) ->
            if $scope.completed_points_member?
                chart.clear()
                redrawChart(chart, $scope.completed_points_member)

        $scope.$on "resize", ->
            getSizes()
            chart.resize()

        $scope.$on "destroy", ->
            $el.off()
    return {link: link}
angular.module('taigaCustomDashboard').directive("tgVelocityMembersGraph", [MemberVelocityDirective])
